---
name: n8n Workflow Automation
description: Orchestrate, validate, and generate n8n workflows enforcing modular flow design, Code Node patterns, MCP server/client integration, AI agent configuration, and credential security.
---

# n8n — Diretrizes Sênior de Automação

## 1. Zero-Trust & Limites de Contexto

- **Antes de criar workflows complexos**, externalize a arquitetura de fluxo em um artefato.
- Faça **micro-commits**: configure um node por vez, teste antes de avançar.
- **Credenciais SEMPRE no credential manager nativo**. Nunca hardcode em parâmetros.
- Para referência da Public API e variáveis de ambiente, consulte `resources/`.

## 2. Princípios

1. **Modularidade**: workflow complexo = sub-workflows via `Execute Workflow`.
2. **Nomenclatura**: nodes como `[Verbo]_[Recurso]` — ex: `Fetch_Orders`, `Send_Alert`.
3. **Nomenclatura workflows**: `[Domínio] - [Ação] - [Descrição]` — ex: `Orders - Sync - Shopify to ERP`.
4. **Versionamento**: exportar JSON e versionar com Git (remover `credentialIds` antes).
5. **Sticky Notes**: documentar decisões e lógica complexa no canvas.

## 3. Code Node — Dogmas

```javascript
// ✅ CERTO — formato de retorno correto, tipado
const items = $input.all();
const results = items
  .filter((item) => item.json.status === "active")
  .map((item) => ({
    json: {
      name: item.json.name.trim(),
      total: item.json.price * item.json.quantity,
      processedAt: $now.toISO(),
    },
  }));

return results; // SEMPRE retornar array de { json: {} }

// ❌ ERRADO — return incorreto + mutação in-place
const items = $input.all();
items[0].json.name = items[0].json.name.trim(); // Mutação direta!
return items[0]; // Retorno único sem array!
```

### Anti-Patterns no Code Node

- ❌ `console.log()` para debug → usar campo `_debug` temporário
- ❌ Modificar items in-place sem retornar → SEMPRE retornar novo array
- ❌ Silenciar erros → usar try/catch com throw para propagar
- ❌ Lógica pesada → quebrar em sub-workflows

### Variáveis Disponíveis

| Variável               | Descrição              |
| ---------------------- | ---------------------- |
| `$json`                | JSON do item atual     |
| `$input.all()`         | Todos os items         |
| `$("Node Name").all()` | Items de node anterior |
| `$env.VARIABLE`        | Variável de ambiente   |
| `$execution.id`        | ID da execução         |
| `$now` / `$today`      | Timestamp (Luxon)      |

## 4. HTTP Request — Padrões

```
// ✅ CERTO — retry, timeout, credencial nativa
Method: POST
URL: {{ $json.baseUrl }}/api/v1/endpoint  (expressão dinâmica)
Authentication: Predefined Credential  (NUNCA hardcode!)
Retry on Fail: 3 tentativas, 1000ms intervalo
Timeout: 60s
```

### Paginação

```
1. Set page = 1
2. HTTP Request → GET /items?page={{ $json.page }}
3. IF → $json.hasMore === true
   ├── true  → Set page + 1 → volta a 2
   └── false → Merge resultados
```

## 5. Webhooks — Segurança

```
// ✅ CERTO — autenticação obrigatória
Webhook → Authentication: Header Auth (API key no credential manager)
         HTTPS via reverse proxy (Nginx/Caddy)
         Validar payload no node IF seguinte

// ❌ ERRADO — webhook aberto sem autenticação
Webhook → sem auth → Process Data  // Qualquer um pode chamar!
```

- **HMAC**: validar para webhooks financeiros/críticos.
- **IP Whitelisting**: via firewall quando possível.
- **Respostas genéricas**: nunca expor dados internos no retorno.

## 6. MCP Server/Client

### Criar MCP Server

```
MCP Server Trigger
  ├── [Tool] Search_Products  (HTTP Request) — descrever claramente!
  ├── [Tool] Create_Order     (Code + HTTP Request)
  └── [Tool] Get_Stock        (PostgreSQL Query)
```

- Cada node downstream vira uma `tool` para AI agents.
- **Descrição** de cada tool é CRÍTICA — o LLM decide qual usar por ela.
- Proteger com Header Auth mínimo.

### Consumir MCP Server (Client)

- Node **MCP Client Tool** dentro de AI Agent.
- Habilitar: `N8N_COMMUNITY_PACKAGES_ALLOW_TOOL_USAGE=true`.

## 7. AI Agents — Padrões

```
Chat/Webhook Trigger
  └── AI Agent
        ├── LLM: OpenAI Chat Model
        ├── Memory: Redis (prod) / Window Buffer (dev)
        └── Tools: HTTP Request, Code, MCP Client, Execute Workflow
```

- **System Prompt**: persona + regras + limites + formato de resposta.
- **Limitar tokens**: controlar custos no LLM.
- **Human-in-the-Loop**: para ações sensíveis (pagamentos, exclusões).

## 8. Error Handling

```
// Obrigatório: workflow global de erros
Error Trigger → Code (extrair detalhes) → Slack/Email (notificar)
```

- Em cada workflow: Settings → Error Workflow → selecionar.
- **Retry on Fail**: erros transientes (rede, rate limit).
- **Continue on Fail**: APENAS com logging. Nunca silenciar.
- **Stop and Error**: para violações de regras de negócio.

## 9. Segurança — Checklist

- [ ] `N8N_ENCRYPTION_KEY` definida e forte
- [ ] HTTPS com TLS via reverse proxy
- [ ] Editor protegido por VPN ou IP allow-list
- [ ] Auth em TODOS os webhooks
- [ ] Credenciais no credential manager (nunca plaintext)
- [ ] `NODE_FUNCTION_ALLOW_EXTERNAL` restrito
- [ ] Atualizar n8n regularmente
