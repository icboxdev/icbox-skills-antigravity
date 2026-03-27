---
name: WhatsApp Unofficial APIs (Evolution API + Baileys)
description: Orchestrate, validate, and integrate unofficial WhatsApp APIs using Evolution API (REST, Docker, multi-instance) and Baileys (TypeScript WebSocket). Enforces anti-ban patterns, webhook security, and message handling best practices.
---

# WhatsApp APIs Não Oficiais — Diretrizes Sênior

## 1. Zero-Trust & Limites de Contexto

- **Antes de integrar**, definir em artefato qual solução usar (Evolution API vs Baileys).
- Faça **micro-commits**: implemente um tipo de mensagem por vez.
- APIs não oficiais podem **banir a conta**. Siga as regras anti-ban rigorosamente.
- Para referência completa de endpoints, consulte `resources/endpoints.md`.

> ⚠️ **APIs não oficiais violam ToS do WhatsApp**. Usar apenas para ferramentas internas, testes, MVPs e automação pessoal.

## 2. Quando Usar Qual

| Critério            | Evolution API          | Baileys                 |
| ------------------- | ---------------------- | ----------------------- |
| **Deploy**          | Docker (REST API)      | Código no seu app (lib) |
| **Multi-instância** | ✅ Nativo              | ❌ Manual               |
| **Webhooks**        | ✅ Nativo              | ❌ Eventos Node.js      |
| **Facilidade**      | ⭐⭐⭐⭐⭐             | ⭐⭐⭐                  |
| **Controle**        | Médio (REST)           | Total (WebSocket)       |
| **Integrações**     | n8n, Chatwoot, Typebot | Manual                  |

**Recomendação**: Evolution API para projetos com REST + Docker. Baileys para controle total em TypeScript.

## 3. Evolution API — Setup

```yaml
# docker-compose.yml (essencial)
services:
  evolution-api:
    image: atendai/evolution-api:latest
    restart: always
    ports:
      - "8080:8080"
    environment:
      - AUTHENTICATION_API_KEY=${EVOLUTION_API_KEY}
      - DATABASE_ENABLED=true
      - DATABASE_PROVIDER=postgresql
      - DATABASE_CONNECTION_URI=${DATABASE_URL}
      - REDIS_ENABLED=true
      - REDIS_URI=redis://redis:6379
```

```typescript
// ✅ CERTO — autenticação via env
const headers = {
  "Content-Type": "application/json",
  apikey: process.env.EVOLUTION_API_KEY, // Via env!
};

// ❌ ERRADO — apikey hardcoded
const headers = { apikey: "minha-chave-aqui" };
```

### Criar instância com webhook

```json
// POST /instance/create — SEMPRE configurar webhook aqui
{
  "instanceName": "minha-instancia",
  "integration": "WHATSAPP-BAILEYS",
  "qrcode": true,
  "webhook": {
    "url": "https://meuapp.com/webhook/whatsapp",
    "enabled": true,
    "events": ["MESSAGES_UPSERT", "CONNECTION_UPDATE"]
  }
}
```

### Enviar mensagem de texto

```json
// POST /message/sendText/{instance}
{
  "number": "5511999999999",
  "text": "Olá! Como posso ajudar?"
}
```

## 4. Baileys — Conexão

```typescript
import makeWASocket, {
  DisconnectReason,
  useMultiFileAuthState,
} from "@whiskeysockets/baileys";
import { Boom } from "@hapi/boom";

async function startWhatsApp() {
  const { state, saveCreds } = await useMultiFileAuthState("./auth_info");
  const sock = makeWASocket({ auth: state, printQRInTerminal: true });

  sock.ev.on("creds.update", saveCreds);

  sock.ev.on("connection.update", ({ connection, lastDisconnect }) => {
    if (connection === "close") {
      const shouldReconnect =
        (lastDisconnect?.error as Boom)?.output?.statusCode !==
        DisconnectReason.loggedOut;
      if (shouldReconnect) startWhatsApp();
    }
  });

  sock.ev.on("messages.upsert", async ({ messages, type }) => {
    if (type !== "notify") return;
    for (const msg of messages) {
      if (msg.key.fromMe) continue;
      const from = msg.key.remoteJid!;
      const text =
        msg.message?.conversation ||
        msg.message?.extendedTextMessage?.text ||
        "";
      console.log(`📩 [${from}]: ${text}`);
    }
  });
}
```

### Enviar mensagens (Baileys)

```typescript
await sock.sendMessage(jid, { text: "Olá!" });
await sock.sendMessage(jid, {
  image: { url: "https://..." },
  caption: "Confira!",
});
await sock.sendMessage(jid, {
  document: { url: "..." },
  mimetype: "application/pdf",
  fileName: "doc.pdf",
});
```

**JID format**: `5511999999999@s.whatsapp.net` (pessoa), `120363...@g.us` (grupo).

## 5. Anti-Ban — Regras de Ouro

```typescript
// ✅ CERTO — delay aleatório entre mensagens
function randomDelay(minMs: number, maxMs: number): Promise<void> {
  const delay = Math.floor(Math.random() * (maxMs - minMs + 1)) + minMs;
  return new Promise((resolve) => setTimeout(resolve, delay));
}

await randomDelay(3000, 7000); // 3-7 segundos
await sock.sendMessage(jid, { text: "Olá!" });

// ❌ ERRADO — envio em massa sem delay
for (const jid of contacts) {
  await sock.sendMessage(jid, { text: "Promoção!" }); // BAN CERTO
}
```

1. **Delay mínimo 3-5s** entre envios
2. **Nunca bulk messaging** para centenas de contatos
3. **Simular typing** (`sock.sendPresenceUpdate('composing', jid)`)
4. **Conta dedicada** — nunca usar conta pessoal
5. **Warm-up** — usar o número manualmente por dias antes de automatizar
6. **Responder mensagens** — contas que só enviam são flagged

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

