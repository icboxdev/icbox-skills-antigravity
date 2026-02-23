---
name: Google Gemini REST API
description: Integrate, validate, and generate Google Gemini AI REST API calls enforcing correct auth headers, model naming, request/response formats, rate limiting, and error handling patterns.
---

# Google Gemini REST API — Skill

## DOGMAS (imperativo, sem exceção)

### Endpoint & Auth

- USE `https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent`
- PASSE a API Key NO HEADER `x-goog-api-key`, NUNCA na query string `?key=`
- SEMPRE inclua `Content-Type: application/json`

### Model Naming

- USE modelos estáveis em produção: `gemini-2.5-flash` (recomendado), `gemini-2.5-pro`
- NUNCA use modelos deprecados: `gemini-2.0-flash` e `gemini-1.5-flash` foram descontinuados em fev/2026
- Para versão fixa, use sufixo `-001`: `gemini-2.5-flash-001`
- O alias `gemini-flash-latest` sempre aponta para o Flash mais recente

### Request Body

- `contents` é ARRAY de objetos `{ role, parts }` — roles: `user` e `model` (NÃO `assistant`)
- `systemInstruction` vai FORA de `contents`, como campo raiz: `{ parts: [{ text }] }`
- `generationConfig` aceita: `temperature`, `maxOutputTokens`, `topP`, `topK`
- NUNCA passe `role: 'system'` dentro de `contents`, use `systemInstruction`

### Response Parsing

- Acesse: `data.candidates[0].content.parts[0].text`
- Verifique `finishReason` — pode ser `STOP`, `MAX_TOKENS`, `SAFETY`

### Error Handling

- **429**: Quota esgotada — implemente retry com delay (campo `retryDelay` na resposta)
- **401/403**: API Key inválida ou sem permissão
- **400**: Request malformado (verifique roles, formato de parts)
- SEMPRE logue o body da resposta de erro para debug
- NUNCA retorne mensagens genéricas — inclua status HTTP e sugestão de ação

### Rate Limits (Free Tier — fev 2026)

- `gemini-2.5-flash`: 10 RPM, 250.000 TPM (free tier pode ser mais restritivo)
- Para produção, ATIVE billing no Google AI Studio (aistudio.google.com)
- Para alto volume, use Vertex AI (endpoint diferente)

## Few-Shot: Request/Response

### ✅ CERTO — Auth por header, modelo correto

```typescript
const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent`;

const response = await fetch(url, {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    "x-goog-api-key": apiKey,
  },
  body: JSON.stringify({
    contents: [{ role: "user", parts: [{ text: "Olá" }] }],
    systemInstruction: { parts: [{ text: "Você é um assistente." }] },
    generationConfig: { temperature: 0.7, maxOutputTokens: 4096 },
  }),
});
```

### ❌ ERRADO — Key na query string, modelo deprecado

```typescript
// NUNCA faça isso:
const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKey}`;
// gemini-2.0-flash deprecado, key exposta na URL
```

### ✅ CERTO — Multi-turn chat

```typescript
const contents = [
  { role: "user", parts: [{ text: "Olá" }] },
  { role: "model", parts: [{ text: "Olá! Como posso ajudar?" }] },
  { role: "user", parts: [{ text: "Me ajude com código" }] },
];
// role 'model' (NÃO 'assistant')
```

### ❌ ERRADO — Role 'assistant' e system em contents

```typescript
// NUNCA faça isso:
const contents = [
  { role: "system", parts: [{ text: "Prompt do sistema" }] }, // System NÃO vai em contents
  { role: "assistant", parts: [{ text: "..." }] }, // É 'model', não 'assistant'
];
```

### ✅ CERTO — Error handling com retry

```typescript
if (!response.ok) {
  const errorBody = await response.text();
  logger.error(`Gemini HTTP ${response.status}: ${errorBody}`);

  if (response.status === 429) {
    // Extrair retryDelay da resposta se disponível
    const parsed = JSON.parse(errorBody);
    const retryDelay = parsed.error?.details?.find(
      (d: Record<string, unknown>) => d["@type"]?.includes("RetryInfo"),
    )?.retryDelay;
    // Implementar retry ou retornar mensagem específica
  }
}
```

## Context Management

- SEMPRE valide que o modelo solicitado é compatível antes de chamar
- Se o modelo começa com `gemini-` → use este skill
- Se o modelo começa com `gpt-` ou `o` → use OpenAI
- CACHE settings por 5 minutos para evitar queries no banco a cada request
- Para streaming, use `:streamGenerateContent?alt=sse` no endpoint

## Zero-Trust

- NUNCA exponha a API Key em logs, respostas ou URLs
- VALIDE `apiKey` antes de fazer o fetch (não pode ser vazia ou undefined)
- SANITIZE conteúdo de `systemInstruction` — não injete dados do usuário diretamente
- LIMITE `maxOutputTokens` a um valor razoável (4096-8192) para controlar custos
