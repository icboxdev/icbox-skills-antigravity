---
name: GOWA — Go WhatsApp Web Multidevice
description: Orchestrate and validate GOWA (go-whatsapp-web-multidevice) integrations — Go-based WhatsApp REST API with Docker, multi-account, HMAC webhooks, MCP server, n8n community node, and Chatwoot. Memory-efficient for ARM/AMD.
---

# GOWA — Go WhatsApp Web Multidevice — Diretrizes Sênior

## 1. Zero-Trust & Limites de Contexto

- **Antes de integrar**, definir o fluxo de mensagens em um artefato.
- Faça **micro-commits**: configure um endpoint por vez.
- **Sempre validar HMAC** nos webhooks. O secret padrão `"secret"` DEVE ser alterado.
- Para referência completa de endpoints e eventos, consulte `resources/api-reference.md`.

## 2. Visão Geral

| Aspecto           | Detalhe                                                                                                          |
| ----------------- | ---------------------------------------------------------------------------------------------------------------- |
| **Linguagem**     | Go (muito eficiente em memória ~30-50MB)                                                                         |
| **Docker Image**  | ~30MB (vs ~400MB Evolution API)                                                                                  |
| **Porta**         | `3000` (REST) / `8080` (MCP)                                                                                     |
| **Multi-account** | ✅ via devices API                                                                                               |
| **MCP Server**    | ✅ Nativo (AI Agents)                                                                                            |
| **n8n Node**      | `@aldinokemal2104/n8n-nodes-gowa`                                                                                |
| **Chatwoot**      | ✅ Nativo                                                                                                        |
| **Repositório**   | [github.com/aldinokemal/go-whatsapp-web-multidevice](https://github.com/aldinokemal/go-whatsapp-web-multidevice) |

## 3. Deploy com Docker

```yaml
services:
  whatsapp:
    image: aldinokemal2104/go-whatsapp-web-multidevice
    restart: always
    ports:
      - "3000:3000"
    volumes:
      - gowa_data:/app/storages
    environment:
      - APP_BASIC_AUTH=${GOWA_AUTH} # admin:secret
      - WHATSAPP_WEBHOOK=${WEBHOOK_URL}
      - WHATSAPP_WEBHOOK_SECRET=${HMAC_SECRET} # ALTERAR do padrão!
      - WHATSAPP_WEBHOOK_EVENTS=message,message.ack
volumes:
  gowa_data:
```

## 4. Autenticação

```bash
# ✅ CERTO — Basic Auth via env
curl -X POST http://localhost:3000/send/message \
  -u "${GOWA_AUTH}" \
  -H "Content-Type: application/json" \
  -d '{"phone": "5511999999999", "message": "Olá!"}'

# ❌ ERRADO — credenciais hardcoded
curl -u admin:secret ...  # Exposto no histórico!
```

## 5. Endpoints Essenciais

| Ação               | Método | Endpoint                    |
| ------------------ | ------ | --------------------------- |
| Login (QR)         | GET    | `/app/login`                |
| Login (código)     | GET    | `/app/login/code?phone=...` |
| Enviar texto       | POST   | `/send/message`             |
| Enviar imagem      | POST   | `/send/image`               |
| Enviar documento   | POST   | `/send/file`                |
| Enviar localização | POST   | `/send/location`            |
| Listar chats       | GET    | `/chat/list`                |
| Criar grupo        | POST   | `/group/create`             |

## 6. Webhooks — Segurança HMAC

```typescript
// ✅ CERTO — validar HMAC SHA256 em TODA request de webhook
import { createHmac } from "node:crypto";

function verifyWebhookSignature(
  body: string,
  signature: string,
  secret: string,
): boolean {
  const expected = createHmac("sha256", secret).update(body).digest("hex");
  return expected === signature;
}

// ❌ ERRADO — aceitar webhook sem verificar assinatura
app.post("/webhook/wa", (req, res) => {
  processMessage(req.body); // Sem verificação!
  res.sendStatus(200);
});
```

### Eventos disponíveis

`message` | `message.reaction` | `message.revoked` | `message.edited` | `message.ack` | `group.participants` | `call.offer`

## 7. MCP Server (AI Agents)

```bash
./whatsapp mcp --host=localhost --port=8080
```

Configurar no cliente MCP:

```json
{ "mcpServers": { "whatsapp": { "url": "http://localhost:8080/sse" } } }
```

Tools disponíveis: `whatsapp_send_text`, `whatsapp_list_chats`, `whatsapp_connection_status`, etc.

## 8. GOWA vs Evolution API

| Critério     | GOWA           | Evolution API        |
| ------------ | -------------- | -------------------- |
| Memória      | ~30-50MB       | ~150-300MB           |
| MCP Server   | ✅             | ❌                   |
| Webhook HMAC | ✅             | ❌                   |
| n8n          | Community node | Webhook              |
| Ecossistema  | Menor          | Maior (Typebot, etc) |

Usar GOWA quando: baixo consumo de memória, MCP, HMAC nativo. Usar Evolution quando: ecossistema Node.js maduro.
