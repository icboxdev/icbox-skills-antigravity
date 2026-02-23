---
name: Webhooks Outbound & Event Bus
description: Architect, implement, and validate Event Bus (in-process pub/sub) and Webhooks Outbound systems with HMAC-SHA256 signing, retry with exponential backoff, delivery logging, and multi-tenant subscription management. Stack-agnostic patterns applicable to any backend framework.
---

# Webhooks Outbound & Event Bus — Skill Sênior

## 1. Propósito Atômico

Esta skill cobre **exclusivamente** a arquitetura de:

- Event Bus in-process (pub/sub)
- Webhooks outbound (HTTP POST assinado para URLs externas)
- Subscription management (CRUD multi-tenant)
- Delivery logging com retry

**NÃO cobre**: webhooks inbound (recebimento), message queues externas (RabbitMQ, Kafka), ou SSE/WebSockets.

---

## 2. Dogmas Arquiteturais

### Event Bus

- O Event Bus é **singleton** — uma única instância por aplicação.
- Dispatch é **SEMPRE assíncrono** — `publish()` nunca bloqueia o caller.
- Cada handler roda em **isolamento** — panic/exception de um handler NÃO derruba outros.
- O bus deve ser **thread-safe** (mutex/lock para registro de handlers).
- Use **wildcard `*`** para handlers que ouvem TODOS os eventos.
- Timestamp é **auto-preenchido** no momento do `publish()`, nunca pelo caller.

### Webhook Dispatcher

- O dispatcher **se registra como handler wildcard** (`subscribeAll`) no Event Bus.
- Ao receber evento, busca subscriptions **ativas** e **não-deletadas** do tenant.
- Filtragem de eventos acontece **no dispatcher**, não no banco.
- Cada delivery roda em **background** (goroutine, task, worker, promise).
- **NUNCA** faça dispatch síncrono — falha de webhook NÃO pode travar operação de domínio.

### Segurança

- O `secret` é retornado **apenas na criação** — JAMAIS no GET /list.
- HMAC é computado sobre o **body inteiro** (bytes brutos do JSON).
- O header de assinatura segue formato: `sha256={hex}`.
- HTTP client tem **timeout de 10 segundos** — nunca ilimitado.
- Response body logado com **truncamento a 512 chars** — previne OOM.
- Secret gerado com **32 bytes criptograficamente seguros**, prefixado: `whsec_`.

### Retry & Delivery

- **3 tentativas** com backoff exponencial: `[0s, 2s, 10s]`.
- Sucesso = status HTTP `2xx` (200-299).
- **Cada tentativa** gera registro em `webhook_deliveries` — nunca sobrescrever.
- Soft delete em subscriptions (campo `deleted_at`) — nunca hard delete.

---

## 3. Estrutura do Evento (Contrato)

```json
{
  "type": "deal.created",
  "tenant_id": "uuid",
  "user_id": "uuid",
  "payload": { "id": "...", "title": "...", "value": 50000 },
  "timestamp": "2025-01-01T00:00:00Z"
}
```

**Tipos (adapte ao domínio):**

```
deal.created | deal.updated | deal.moved | deal.won | deal.lost | deal.deleted
stage.created | stage.deleted
goal.set | goal.achieved
contact.created | contact.updated
```

---

## 4. Data Model

### webhook_subscriptions

```sql
CREATE TABLE webhook_subscriptions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID NOT NULL REFERENCES tenants(id),
  created_by  UUID NOT NULL REFERENCES users(id),
  name        VARCHAR(255) NOT NULL,
  url         TEXT NOT NULL,
  secret      VARCHAR(255) NOT NULL,
  events      TEXT[] NOT NULL DEFAULT '{}',
  is_active   BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at  TIMESTAMPTZ
);

CREATE INDEX idx_webhook_subs_tenant ON webhook_subscriptions(tenant_id) WHERE deleted_at IS NULL;
```

### webhook_deliveries

```sql
CREATE TABLE webhook_deliveries (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subscription_id UUID NOT NULL REFERENCES webhook_subscriptions(id),
  event_type      VARCHAR(100) NOT NULL,
  status_code     INT NOT NULL DEFAULT 0,
  response_body   TEXT DEFAULT '',
  latency_ms      INT NOT NULL DEFAULT 0,
  attempt         INT NOT NULL DEFAULT 1,
  success         BOOLEAN NOT NULL DEFAULT false,
  error           TEXT DEFAULT '',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_webhook_del_sub ON webhook_deliveries(subscription_id, created_at DESC);
```

---

## 5. API REST

| Endpoint                            | Método | Body/Params               | Resposta                                      |
| ----------------------------------- | ------ | ------------------------- | --------------------------------------------- |
| `/settings/webhooks`                | POST   | `{ name, url, events[] }` | `201` com `{ id, name, url, secret, events }` |
| `/settings/webhooks`                | GET    | —                         | Lista (SEM secret)                            |
| `/settings/webhooks/:id`            | DELETE | —                         | `204` soft delete                             |
| `/settings/webhooks/:id/toggle`     | PATCH  | —                         | `200` com subscription atualizada             |
| `/settings/webhooks/:id/deliveries` | GET    | —                         | Últimas 50 entregas                           |

---

## 6. Few-Shot: Event Bus

```typescript
// ✅ CERTO — Dispatch assíncrono com isolamento
class EventBus {
  private handlers = new Map<string, Handler[]>();

  publish(event: Event): void {
    event.timestamp = new Date();
    const targets = [
      ...(this.handlers.get(event.type) || []),
      ...(this.handlers.get("*") || []),
    ];
    for (const handler of targets) {
      // Cada handler em background, com error boundary
      setImmediate(() => {
        try {
          handler(event);
        } catch (err) {
          logger.error("handler panic", { type: event.type, err });
        }
      });
    }
  }
}

// ❌ ERRADO — Dispatch síncrono, sem isolamento
class EventBus {
  publish(event: Event): void {
    for (const handler of this.handlers.get(event.type) || []) {
      handler(event); // Bloqueia, e se handler falhar, derruba tudo
    }
  }
}
```

---

## 7. Few-Shot: HMAC Signing

```typescript
// ✅ CERTO — HMAC-SHA256 sobre body bruto
function signPayload(secret: string, body: Buffer): string {
  const hmac = crypto.createHmac("sha256", secret);
  hmac.update(body);
  return "sha256=" + hmac.digest("hex");
}

// Headers enviados:
// X-AppName-Event: deal.created
// X-AppName-Signature: sha256=a1b2c3...
// Content-Type: application/json

// ❌ ERRADO — HMAC sobre string parsed (pode alterar encoding)
function signPayload(secret: string, data: object): string {
  return crypto
    .createHmac("sha256", secret)
    .update(JSON.stringify(data)) // Re-serialização muda a assinatura!
    .digest("hex");
}
```

---

## 8. Few-Shot: Retry com Backoff

```typescript
// ✅ CERTO — 3 tentativas, backoff, log cada attempt
async function deliver(
  url: string,
  secret: string,
  payload: Buffer,
): Promise<void> {
  const backoffs = [0, 2000, 10000]; // ms

  for (let attempt = 0; attempt < backoffs.length; attempt++) {
    if (backoffs[attempt] > 0) await sleep(backoffs[attempt]);

    const start = Date.now();
    try {
      const res = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-App-Signature": signPayload(secret, payload),
        },
        body: payload,
        signal: AbortSignal.timeout(10_000),
      });
      const body = (await res.text()).slice(0, 512); // Truncar!
      const success = res.status >= 200 && res.status < 300;

      await logDelivery({
        attempt: attempt + 1,
        status: res.status,
        body,
        success,
        latency: Date.now() - start,
      });
      if (success) return;
    } catch (err) {
      await logDelivery({
        attempt: attempt + 1,
        status: 0,
        error: err.message,
        success: false,
        latency: Date.now() - start,
      });
    }
  }
}

// ❌ ERRADO — Sem retry, sem log, sem timeout
async function deliver(url: string, payload: object): Promise<void> {
  await fetch(url, { method: "POST", body: JSON.stringify(payload) });
}
```

---

## 9. Arquitetura Visual

```
┌──────────────────────────────────────────────────────────────┐
│                        APLICAÇÃO                             │
│                                                              │
│  ┌──────────┐   publish()   ┌───────────┐  subscribeAll()   │
│  │  Service  │ ────────────►│ Event Bus │◄────────────────┐ │
│  │  (Domain) │              │ (Pub/Sub)  │                 │ │
│  └──────────┘              └───────────┘                 │ │
│                                                           │ │
│                                            ┌──────────────┤ │
│                                            │  Webhook     │ │
│                                            │  Dispatcher  │ │
│                                            └──────┬───────┘ │
│                                                   │         │
│  ┌───────────────────┐  query active subs         │         │
│  │ webhook_subscriptions│◄────────────────────────┘         │
│  └───────────────────┘                                      │
│  ┌───────────────────┐  log each attempt                    │
│  │ webhook_deliveries  │◄─────────────────────              │
│  └───────────────────┘                                      │
└───────────────────────────────────┬──────────────────────────┘
                                    │ HTTP POST + HMAC
                                    ▼
                          ┌──────────────────┐
                          │ Endpoint Externo  │
                          │ (n8n, Zapier...)  │
                          └──────────────────┘
```

---

## 10. Verificação Obrigatória

Após implementar, execute esta sequência de testes:

1. `POST /settings/webhooks` → Criar webhook → secret retornado
2. `GET /settings/webhooks` → Listar → secret NÃO aparece
3. `PATCH /:id/toggle` → Desativar → `is_active: false`
4. `PATCH /:id/toggle` → Reativar → `is_active: true`
5. `GET /:id/deliveries` → Vazio
6. Disparar evento de domínio → Verificar delivery no endpoint externo
7. `GET /:id/deliveries` → Registros com `success: true`
8. `DELETE /:id` → Soft delete
9. `GET /settings/webhooks` → Não lista o deletado

---

## 11. Frontend (Settings → Webhooks)

### Componentes necessários:

- **WebhookList** — tabela com nome, URL, eventos (badges), toggle, ações
- **CreateWebhookDialog** — form com nome, URL, checkboxes de eventos
- **SecretRevealDialog** — exibido pós-criação, botão copiar, aviso "só mostra uma vez"
- **DeliveriesDialog** — histórico com status code (badge verde/vermelho), latência, tentativa
- **EmptyState** — ícone + descrição + botão "Criar primeiro webhook"

### Regras UI:

- Toggle switch inline para ativar/desativar (sem page reload)
- Botão delete com **dialog de confirmação** (nunca `confirm()` nativo)
- Secret exibido com `font-family: monospace` e botão Copy
- Delivery status: verde `2xx`, vermelho outros, cinza `0` (timeout)
