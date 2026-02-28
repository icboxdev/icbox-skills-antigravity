---
name: WAHA WhatsApp HTTP API
description: Orchestrate, validate, and integrate WAHA (WhatsApp HTTP API) REST sessions, messaging, media, webhooks, and HMAC authentication. Covers Docker deployment, multi-session management, QR code pairing, and event handling.
---

# WAHA WhatsApp HTTP API

## Overview

WAHA (WhatsApp HTTP API) is a self-hosted, open-source REST API for WhatsApp Web automation. It runs in Docker and supports multiple WhatsApp sessions, QR code authentication, text/media messaging, and webhook events.

- **GitHub**: https://github.com/devlikeapro/waha
- **Docs**: https://waha.devlike.pro
- **Docker Image**: `devlikeapro/waha` (CORE) / `devlikeapro/waha-plus` (PLUS)
- **Default Port**: `3000`
- **Swagger**: `http://<host>:3000/` (auto-generated OpenAPI)

---

## Architecture Dogmas

### Authentication

- USE `X-Api-Key` header for ALL API requests.
- NEVER expose the API key in client-side code.
- SET `WHATSAPP_API_KEY` environment variable on Docker container.

### Session Management

- Sessions are the core abstraction — each session = one WhatsApp account.
- Session names act as IDs (unique per server).
- Lifecycle: `STOPPED` → `STARTING` → `SCAN_QR_CODE` → `WORKING` → `FAILED`.
- USE `POST /api/sessions` to create, with webhook config inline.
- USE `DELETE /api/sessions/{session}` to remove.
- USE `POST /api/sessions/{session}/stop` to stop without deleting.

### QR Code Pairing

- GET `/api/{session}/auth/qr` returns QR for scanning.
- Accept `image/png` for binary, `application/json` for base64.
- `?format=raw` returns raw QR string value.
- QR expires: first in 60s, then 20s each, up to 6 total → FAILED.
- On `session.status` with `SCAN_QR_CODE`, refresh QR via API.

### Messaging

- All message endpoints require `session` and `chatId` in body.
- chatId format: `<phone>@c.us` (individual) or `<id>@g.us` (group).
- Phone numbers must include country code, no leading `+` or `0`.

### Webhooks

- Configure per-session via `config.webhooks[]` on `POST /api/sessions`.
- Or globally via `WHATSAPP_HOOK_URL` environment variable.
- HMAC auth: `config.webhooks[].hmac.key` → headers `X-Webhook-Hmac` (sha512).
- Event payload: `{ event, session, engine, me, payload, environment }`.
- Retries configurable: `policy` (constant/linear), `delaySeconds`, `attempts`.

---

## Core Endpoints Reference

### Sessions

| Method   | Endpoint                          | Description              |
| -------- | --------------------------------- | ------------------------ |
| `POST`   | `/api/sessions`                   | Create and start session |
| `GET`    | `/api/sessions`                   | List all sessions        |
| `GET`    | `/api/sessions/{session}`         | Get session details      |
| `PUT`    | `/api/sessions/{session}`         | Update session config    |
| `DELETE` | `/api/sessions/{session}`         | Delete session           |
| `POST`   | `/api/sessions/{session}/start`   | Start stopped session    |
| `POST`   | `/api/sessions/{session}/stop`    | Stop session             |
| `POST`   | `/api/sessions/{session}/restart` | Restart session          |
| `POST`   | `/api/sessions/{session}/logout`  | Logout (unlink device)   |

### Authentication / QR

| Method | Endpoint                            | Description                    |
| ------ | ----------------------------------- | ------------------------------ |
| `GET`  | `/api/{session}/auth/qr`            | Get QR code (image/json/raw)   |
| `GET`  | `/api/{session}/auth/qr?format=raw` | Get raw QR string              |
| `POST` | `/api/{session}/auth/request-code`  | Request pairing code           |
| `GET`  | `/api/screenshot`                   | Get screenshot of WhatsApp Web |

### Messaging

| Method | Endpoint                | Body Fields                                             |
| ------ | ----------------------- | ------------------------------------------------------- |
| `POST` | `/api/sendText`         | `session, chatId, text`                                 |
| `POST` | `/api/sendImage`        | `session, chatId, file: {url\|data\|mimetype}, caption` |
| `POST` | `/api/sendFile`         | `session, chatId, file: {url\|data\|mimetype}, caption` |
| `POST` | `/api/sendVideo`        | `session, chatId, file: {url\|data}, caption`           |
| `POST` | `/api/sendVoice`        | `session, chatId, file: {url\|data}`                    |
| `POST` | `/api/sendSeen`         | `session, chatId`                                       |
| `POST` | `/api/sendPoll`         | `session, chatId, ...`                                  |
| `POST` | `/api/sendLocation`     | `session, chatId, lat, lng, title`                      |
| `POST` | `/api/sendContactVcard` | `session, chatId, contacts`                             |

### Status & Info

| Method | Endpoint             | Description              |
| ------ | -------------------- | ------------------------ |
| `GET`  | `/api/server/status` | Server health check      |
| `GET`  | `/api/{session}/me`  | Get connected phone info |

---

## Webhook Events

| Event              | Description                                                           |
| ------------------ | --------------------------------------------------------------------- |
| `session.status`   | Session status changed (STOPPED/STARTING/SCAN_QR_CODE/WORKING/FAILED) |
| `message`          | Incoming message (text/media) — only from contacts                    |
| `message.any`      | Any message (including sent by API)                                   |
| `message.ack`      | Message delivery/read receipt                                         |
| `message.reaction` | Message reaction added                                                |
| `message.revoked`  | Message deleted                                                       |
| `message.waiting`  | Message pending                                                       |
| `message.edited`   | Message edited                                                        |
| `group.v2.join`    | User joined group                                                     |
| `group.v2.leave`   | User left group                                                       |
| `presence.update`  | Online/typing status                                                  |
| `call.received`    | Incoming call                                                         |

### Webhook Payload Structure

```json
{
  "event": "message",
  "session": "default",
  "engine": "WEBJS",
  "me": { "id": "5511999999999@c.us", "pushName": "Bot" },
  "payload": {
    "id": "true_5511999999999@c.us_AAAA",
    "timestamp": 1700000000,
    "from": "5511888888888@c.us",
    "fromMe": false,
    "to": "5511999999999@c.us",
    "body": "Hello!",
    "hasMedia": false
  },
  "environment": { "version": "2025.1", "engine": "WEBJS", "tier": "PLUS" }
}
```

### HMAC Verification (SHA-512)

```typescript
import { createHmac } from "crypto";

function verifyWahaHmac(
  rawBody: string,
  signature: string,
  secret: string,
): boolean {
  const expected = createHmac("sha512", secret).update(rawBody).digest("hex");
  return expected === signature;
}

// Headers to check:
// X-Webhook-Hmac: <hex_signature>
// X-Webhook-Hmac-Algorithm: sha512
```

---

## Docker Deployment

```yaml
# docker-compose.yml
services:
  waha:
    image: devlikeapro/waha
    ports:
      - "3000:3000"
    environment:
      WHATSAPP_API_KEY: your-secret-key
      WHATSAPP_RESTART_ALL_SESSIONS: "True"
      # Global webhook (optional)
      WHATSAPP_HOOK_URL: https://your-app.com/api/webhooks/waha
      WHATSAPP_HOOK_EVENTS: "message,session.status"
      WHATSAPP_HOOK_HMAC_KEY: your-hmac-secret
    volumes:
      - waha_data:/app/.sessions

volumes:
  waha_data:
```

---

## Few-Shot Examples

### ✅ CORRECT: Create Session with Webhook

```typescript
const response = await fetch(`${baseUrl}/api/sessions`, {
  method: "POST",
  headers: {
    "X-Api-Key": apiKey,
    "Content-Type": "application/json",
  },
  body: JSON.stringify({
    name: sessionName,
    config: {
      webhooks: [
        {
          url: `${appUrl}/api/webhooks/waha`,
          events: ["message", "session.status"],
          hmac: { key: webhookSecret },
        },
      ],
    },
  }),
});
```

### ❌ WRONG: Missing session name, no webhook config

```typescript
// BAD — no session name, no webhook
const response = await fetch(`${baseUrl}/api/sessions/start`, {
  // wrong endpoint
  method: "POST",
  headers: { Authorization: `Bearer ${apiKey}` }, // wrong header
});
```

### ✅ CORRECT: Send Text Message

```typescript
const response = await fetch(`${baseUrl}/api/sendText`, {
  method: "POST",
  headers: {
    "X-Api-Key": apiKey,
    "Content-Type": "application/json",
  },
  body: JSON.stringify({
    session: sessionName,
    chatId: `${phoneNumber}@c.us`,
    text: "Hello from WAHA!",
  }),
});
```

### ❌ WRONG: Wrong chatId format

```typescript
// BAD — missing @c.us suffix, using phone with +
const response = await fetch(`${baseUrl}/api/sendText`, {
  method: "POST",
  body: JSON.stringify({
    session: sessionName,
    chatId: "+5511999999999", // WRONG — must be 5511999999999@c.us
    text: "Hello",
  }),
});
```

### ✅ CORRECT: Get QR as Base64

```typescript
const response = await fetch(`${baseUrl}/api/${sessionName}/auth/qr`, {
  headers: {
    "X-Api-Key": apiKey,
    Accept: "application/json",
  },
});
const data = await response.json();
// data.value = "data:image/png;base64,..."
```

### ✅ CORRECT: Send Image by URL

```typescript
const response = await fetch(`${baseUrl}/api/sendImage`, {
  method: "POST",
  headers: {
    "X-Api-Key": apiKey,
    "Content-Type": "application/json",
  },
  body: JSON.stringify({
    session: sessionName,
    chatId: `${phone}@c.us`,
    file: { url: "https://example.com/image.jpg" },
    caption: "Check this out!",
  }),
});
```

---

## Evolution vs WAHA — Comparison

| Feature         | Evolution API                          | WAHA                               |
| --------------- | -------------------------------------- | ---------------------------------- |
| Auth Header     | `apikey` header                        | `X-Api-Key` header                 |
| Create Instance | `POST /instance/create`                | `POST /api/sessions`               |
| Delete Instance | `DELETE /instance/delete/{name}`       | `DELETE /api/sessions/{name}`      |
| QR Code         | `GET /instance/connect/{name}`         | `GET /api/{name}/auth/qr`          |
| Instance Status | `GET /instance/connectionState/{name}` | `GET /api/sessions/{name}`         |
| Send Text       | `POST /message/sendText/{name}`        | `POST /api/sendText`               |
| Send Media      | `POST /message/sendMedia/{name}`       | `POST /api/sendImage`              |
| Webhook Config  | Instance-level or settings             | Session config or global env       |
| HMAC Validation | SHA-256 via `x-hub-signature-256`      | SHA-512 via `X-Webhook-Hmac`       |
| chatId format   | `5511999999999@s.whatsapp.net`         | `5511999999999@c.us`               |
| Disconnect      | `DELETE /instance/logout/{name}`       | `POST /api/sessions/{name}/logout` |

---

## Zero-Trust & Security

- ALWAYS validate `X-Webhook-Hmac` header on incoming webhooks.
- NEVER trust webhook payload without HMAC verification.
- ENCRYPT API keys at rest (AES-256-GCM).
- USE separate HMAC secrets per session/connection.
- ROTATE API keys periodically.
- LIMIT webhook events to only what you need (avoid `*`).

---

## Context Management

- When adapting between Evolution and WAHA, use an Adapter pattern.
- Both share the same conceptual operations: create, connect (QR), send, receive (webhook).
- The adapter should normalize chatId formats (`@s.whatsapp.net` ↔ `@c.us`).
- The adapter should normalize webhook payloads to a common internal format.
