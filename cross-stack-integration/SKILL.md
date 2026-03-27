---
name: Cross-Stack Integration (Rust ↔ Node.js)
description: Architect, validate, and generate integration patterns between Rust (Axum) and Node.js (Fastify/NestJS) backends. Covers M2M authentication, compensating transactions, retry/circuit breaker, type contract alignment (Serde ↔ Zod), and health check patterns.
---

# Cross-Stack Integration — Diretrizes Sênior

## 1. Princípio Zero: Dois Backends, Uma Verdade

Quando Rust e Node.js coexistem no mesmo ecossistema, a **fronteira entre serviços** é onde nascem os bugs mais difíceis. Esta skill trata exclusivamente da comunicação e integração entre backends de stacks diferentes.

- **Contratos explícitos**: Os tipos de request/response DEVEM ser definidos em AMBOS os lados (Serde struct + Zod schema).
- **Fail-fast**: Se o serviço remoto não responde, falhe rápido. Não espere timeout padrão de 30s.
- **Compensação > Transação**: Atomicidade entre serviços HTTP é impossível. Use compensating transactions.
- **Health Check**: Cada serviço DEVE verificar a disponibilidade do outro no startup.

## 2. M2M Authentication (Machine-to-Machine)

### Master Key Pattern

```
Serviço A (Rust/Axum)  →  POST /api/internal/resource
                           Header: X-Master-Key: <shared_secret>
                       →  Serviço B (Fastify)
```

#### Lado Rust (Client — reqwest)

```rust
// CERTO: reqwest com Master Key + timeout
let response = state.http_client
    .post(format!("{}/api/internal/allocations", storage_url))
    .header("X-Master-Key", &state.config.storage_master_key)
    .header("Content-Type", "application/json")
    .timeout(Duration::from_secs(10))
    .json(&CreateAllocationRequest {
        tenant_slug: slug.clone(),
        node_id: node.id,
    })
    .send()
    .await
    .context("Failed to call Storage API")?;

if !response.status().is_success() {
    let error_body = response.text().await.unwrap_or_default();
    return Err(AppError::External(format!("Storage API error: {error_body}")));
}

// ERRADO: Sem timeout (request pendurado indefinidamente)
// ERRADO: .unwrap() no response sem verificar status
```

#### Lado Node.js (Server — Fastify)

```typescript
// CERTO: Plugin de auth com timing-safe comparison
import fp from "fastify-plugin";
import { timingSafeEqual } from "node:crypto";

export default fp(async (fastify) => {
  fastify.addHook("onRequest", async (request, reply) => {
    // Pular health check
    if (request.url === "/health") return;

    const key = request.headers["x-master-key"] as string | undefined;
    if (!key || !safeCompare(key, env.MASTER_KEY)) {
      reply.code(401).send({ error: { code: "UNAUTHORIZED", message: "Invalid master key" } });
    }
  });
});

// ERRADO: if (key !== env.MASTER_KEY) — timing attack
```

## 3. Compensating Transactions

Atomicidade entre serviços HTTP é **impossível**. Use o padrão Create → Call → Compensate.

```
1. Criar registro LOCAL (DB do Provisioner)
2. Chamar serviço REMOTO (API do Storage)
3. Se remoto FALHAR → Deletar registro local (compensação)
```

### Exemplo Rust

```rust
// CERTO: Compensating deletion
pub async fn allocate_tenant(
    pool: &PgPool,
    http: &reqwest::Client,
    request: &AllocateRequest,
) -> Result<Allocation, AppError> {
    // 1. Criar local
    let allocation = sqlx::query_as!(
        Allocation,
        "INSERT INTO allocations (tenant_slug, node_id) VALUES ($1, $2) RETURNING *",
        request.tenant_slug, request.node_id
    )
    .fetch_one(pool)
    .await?;

    // 2. Chamar remoto
    let remote_result = http
        .post(&format!("{}/api/v1/provision", request.storage_url))
        .header("X-Master-Key", &request.master_key)
        .json(&ProvisionPayload { tenant_slug: &request.tenant_slug })
        .timeout(Duration::from_secs(15))
        .send()
        .await;

    // 3. Compensar se falhou
    match remote_result {
        Ok(resp) if resp.status().is_success() => Ok(allocation),
        _ => {
            // Compensating delete
            sqlx::query!("DELETE FROM allocations WHERE id = $1", allocation.id)
                .execute(pool)
                .await?;
            Err(AppError::External("Storage provisioning failed, rolled back".into()))
        }
    }
}

// ERRADO: Criar local sem compensar se remoto falha (registro órfão)
```

## 4. Type Contract Alignment (Serde ↔ Zod)

### Regra de Ouro

O contrato de tipos entre Rust e Node.js DEVE ser espelhado exatamente:

```rust
// Rust (Serde) — Lado que ENVIA
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CreateAllocationRequest {
    pub tenant_slug: String,
    pub node_id: Uuid,
    pub allocated_at: DateTime<Utc>,
}
```

```typescript
// TypeScript (Zod) — Lado que RECEBE
const createAllocationSchema = z.object({
  tenantSlug: z.string().min(2),    // camelCase! (Serde rename_all)
  nodeId: z.string().uuid(),
  allocatedAt: z.string().datetime(),
});
```

### Gotchas de Serialização

| Rust Type | JSON | TypeScript Type | ⚠️ Cuidado |
|---|---|---|---|
| `Uuid` | `"string"` | `z.string().uuid()` | Serde serializa como string |
| `DateTime<Utc>` | `"2024-01-01T00:00:00Z"` | `z.string().datetime()` | Formato ISO 8601 |
| `Option<T>` | campo ausente ou `null` | `z.optional()` | Use `skip_serializing_if` |
| `i64` | number | `z.number().int()` | JS perde precisão > 2^53 |
| `HashMap` | object | `z.record()` | Chaves sempre string |

```rust
// CERTO: Serde alinhado com expectativa do TypeScript
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Response {
    pub tenant_id: Uuid,              // → "tenantId": "uuid-string"
    #[serde(skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,  // → ausente se None
}

// ERRADO: snake_case no JSON quando Node espera camelCase
```

## 5. Retry com Exponential Backoff

```rust
// CERTO: Retry com backoff para chamadas inter-service
pub async fn call_with_retry<F, Fut, T>(
    max_retries: u32,
    operation: F,
) -> Result<T, AppError>
where
    F: Fn() -> Fut,
    Fut: std::future::Future<Output = Result<T, AppError>>,
{
    let mut attempt = 0;
    loop {
        match operation().await {
            Ok(result) => return Ok(result),
            Err(e) if attempt < max_retries => {
                attempt += 1;
                let delay = Duration::from_millis(100 * 2u64.pow(attempt));
                tracing::warn!("Retry {attempt}/{max_retries} after {delay:?}: {e}");
                tokio::time::sleep(delay).await;
            }
            Err(e) => return Err(e),
        }
    }
}
```

## 6. Health Check Between Services

```rust
// CERTO: Verificar disponibilidade do serviço parceiro no startup
pub async fn check_storage_health(config: &Config) -> Result<(), AppError> {
    let resp = reqwest::Client::new()
        .get(format!("{}/health", config.storage_url))
        .timeout(Duration::from_secs(5))
        .send()
        .await
        .context("Storage service unreachable")?;

    if !resp.status().is_success() {
        return Err(AppError::External("Storage service unhealthy".into()));
    }

    tracing::info!("✅ Storage service healthy at {}", config.storage_url);
    Ok(())
}
```

```typescript
// Node.js: Health endpoint que verifica dependências
fastify.get("/health", async () => {
  const dbOk = await prisma.$queryRaw`SELECT 1`.then(() => true).catch(() => false);
  const redisOk = await redis.ping().then(() => true).catch(() => false);

  return {
    status: dbOk && redisOk ? "healthy" : "degraded",
    services: { database: dbOk, redis: redisOk },
  };
});
```

## 7. Error Response Envelope

Todos os serviços DEVEM retornar o mesmo formato de erro:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Human-readable message",
    "details": {}
  }
}
```

### Parsing de erros do serviço remoto (Rust)

```rust
#[derive(Deserialize)]
struct RemoteErrorResponse {
    error: RemoteError,
}

#[derive(Deserialize)]
struct RemoteError {
    code: String,
    message: String,
}

// Uso:
if !response.status().is_success() {
    let error: RemoteErrorResponse = response.json().await
        .unwrap_or(RemoteErrorResponse {
            error: RemoteError {
                code: "UNKNOWN".into(),
                message: "Failed to parse remote error".into(),
            },
        });
    return Err(AppError::External(format!("[{}] {}", error.error.code, error.error.message)));
}
```

## 8. Constraints — O que NUNCA Fazer

- ❌ NUNCA assuma que o serviço remoto está disponível — sempre verifique health
- ❌ NUNCA faça chamadas HTTP sem timeout explícito (máx 15s para inter-service)
- ❌ NUNCA use transação DB para garantir atomicidade entre serviços HTTP
- ❌ NUNCA use snake_case em JSON quando Node espera camelCase (Serde: `rename_all`)
- ❌ NUNCA ignore status codes da resposta HTTP (verificar `.is_success()`)
- ❌ NUNCA compare Master Keys com `==` (timing attack) — use `timingSafeEqual`
- ❌ NUNCA passe `i64` grandes via JSON para JavaScript (perda de precisão > 2^53)
- ❌ NUNCA crie registro local sem compensar se a chamada remota falhar

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.
