---
name: WhatsApp Cloud API (Meta Official)
description: Orchestrate and validate integrations with the official WhatsApp Business Cloud API (Meta). Covers authentication, message types, webhooks, templates, interactive messages, and security best practices.
---

# WhatsApp Cloud API (Meta) — Diretrizes Sênior

## 1. Zero-Trust & Limites de Contexto

- **Antes de integrar**, definir o fluxo de mensagens em um artefato (quem envia, quem recebe, quais templates).
- Faça **micro-commits**: implemente um tipo de mensagem por vez.
- **Tokens temporários expiram em 24h**. Em produção, usar System User Token permanente.
- Para referência completa de payloads, consulte `resources/message-types.md`.

## 2. Autenticação

```typescript
// ✅ CERTO — token permanente via env
const headers = {
  Authorization: `Bearer ${process.env.WHATSAPP_TOKEN}`,
  "Content-Type": "application/json",
};

const BASE_URL = `https://graph.facebook.com/v21.0/${process.env.PHONE_NUMBER_ID}`;

// ❌ ERRADO — token temporário hardcoded
const token = "EAABs...<temporary>"; // Expira em 24h!
```

**Token permanente**: Meta Business Suite → System Users → Generate Token (whatsapp_business_messaging).

## 3. Envio de Mensagens

### Template (fora da janela de 24h)

```typescript
// ✅ CERTO — template pré-aprovado com componentes
await fetch(`${BASE_URL}/messages`, {
  method: "POST",
  headers,
  body: JSON.stringify({
    messaging_product: "whatsapp",
    to: "5511999999999",
    type: "template",
    template: {
      name: "order_confirmation",
      language: { code: "pt_BR" },
      components: [
        {
          type: "body",
          parameters: [
            { type: "text", text: "João" },
            { type: "text", text: "#12345" },
          ],
        },
      ],
    },
  }),
});
```

### Texto (dentro da janela de 24h)

```typescript
await fetch(`${BASE_URL}/messages`, {
  method: "POST",
  headers,
  body: JSON.stringify({
    messaging_product: "whatsapp",
    to: "5511999999999",
    type: "text",
    text: { body: "Olá! Como posso ajudar?" },
  }),
});
```

### Interactive (botões/lista)

```json
{
  "messaging_product": "whatsapp",
  "to": "5511999999999",
  "type": "interactive",
  "interactive": {
    "type": "button",
    "body": { "text": "Escolha uma opção:" },
    "action": {
      "buttons": [
        { "type": "reply", "reply": { "id": "btn_1", "title": "Vendas" } },
        { "type": "reply", "reply": { "id": "btn_2", "title": "Suporte" } }
      ]
    }
  }
}
```

## 4. Webhooks — Recebimento

### Verificação (GET)

```typescript
app.get("/webhook/whatsapp", (req, res) => {
  const mode = req.query["hub.mode"];
  const token = req.query["hub.verify_token"];
  const challenge = req.query["hub.challenge"];

  if (mode === "subscribe" && token === process.env.WEBHOOK_VERIFY_TOKEN) {
    res.status(200).send(challenge);
  } else {
    res.sendStatus(403);
  }
});
```

### Mensagem recebida (POST)

```typescript
app.post("/webhook/whatsapp", (req, res) => {
  // Retornar 200 IMEDIATAMENTE para evitar retry
  res.sendStatus(200);

  const entry = req.body?.entry?.[0];
  const change = entry?.changes?.[0]?.value;
  const message = change?.messages?.[0];

  if (!message) return; // Status update, não mensagem

  const from = message.from; // "5511999999999"
  const text = message.text?.body; // Conteúdo da mensagem
  const type = message.type; // "text", "image", "interactive", etc

  // Processar async (fila/queue)
  processMessage({ from, text, type }).catch(console.error);
});
```

## 5. Regras de Negócio Críticas

| Regra              | Detalhe                                                             |
| ------------------ | ------------------------------------------------------------------- |
| **Janela de 24h**  | Só enviar texto/mídia livre se o contato respondeu nas últimas 24h  |
| **Fora da janela** | Apenas templates pré-aprovados pela Meta                            |
| **Rate limits**    | 80 msgs/seg (Business), 1000/seg (Enterprise)                       |
| **Formato número** | Código do país + DDD + número, sem `+`, sem espaço: `5511999999999` |
| **Idempotência**   | Usar `message_id` para deduplicar webhooks                          |

## 6. Segurança

- Validar **assinatura HMAC** (`X-Hub-Signature-256`) em webhooks de produção.
- Secrets via env vars. Nunca hardcode tokens.
- HTTPS obrigatório no endpoint de webhook.
- Rate limiting no servidor para evitar loops de webhook.
- Responder `200` antes de processar (evitar retries do Meta).
