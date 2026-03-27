---
name: Redis Rust (Cache, PubSub, Jobs)
description: Validate, generate, and optimize Redis integrations in Rust using redis-rs. Covers async connection pool, caching patterns, pub/sub for real-time events, session management, job queue with retry, rate limiting, and distributed locks.
---

# Redis Rust — Diretrizes Sênior

## 1. Princípio Zero: Redis é Volátil

Redis é cache e message broker, NÃO database. Dados em Redis podem ser perdidos. Todo dado crítico vive no PostgreSQL. Redis acelera.

- **Skill complementar**: Leia `axum-web` e `rust-lang` junto.
- **Async obrigatório**: Sempre use feature `tokio-comp` para async I/O.
- **Connection pool**: NUNCA crie conexões ad-hoc. Use `ConnectionManager` com pool.

## 2. Cargo.toml

```toml
[dependencies]
redis = { version = "0.27", features = ["tokio-comp", "connection-manager"] }
deadpool-redis = "0.18"   # Pool manager
```

## 3. Connection Pool

```rust
use deadpool_redis::{Config, Pool, Runtime};

pub fn create_redis_pool(url: &str) -> Pool {
    let cfg = Config::from_url(url);
    cfg.create_pool(Some(Runtime::Tokio1))
       .expect("Failed to create Redis pool")
}

// No AppState
pub struct AppState {
    pub db: PgPool,
    pub redis: deadpool_redis::Pool,
}
```

## 4. Cache Pattern — Tenant-Scoped

```rust
use redis::AsyncCommands;

const CACHE_TTL: u64 = 300; // 5 min

pub async fn get_cached_or_fetch<T: serde::Serialize + serde::de::DeserializeOwned>(
    redis: &deadpool_redis::Pool,
    key: &str,
    ttl: u64,
    fetch: impl std::future::Future<Output = Result<T, anyhow::Error>>,
) -> Result<T, anyhow::Error> {
    let mut conn = redis.get().await?;

    // Tentar cache
    if let Ok(cached) = conn.get::<_, String>(key).await {
        if let Ok(value) = serde_json::from_str::<T>(&cached) {
            return Ok(value);
        }
    }

    // Cache miss — fetch do banco
    let value = fetch.await?;

    // Salvar no cache
    let serialized = serde_json::to_string(&value)?;
    conn.set_ex::<_, _, ()>(key, &serialized, ttl).await.ok();

    Ok(value)
}

// Uso com tenant scoping
let key = format!("tenant:{}:plan_modules", tenant_id);
let modules = get_cached_or_fetch(&state.redis, &key, CACHE_TTL, async {
    PlanRepository::get_modules(&state.db, tenant_id).await
}).await?;
```

## 5. Cache Invalidation

```rust
// Invalidar chave específica
pub async fn invalidate(redis: &deadpool_redis::Pool, key: &str) -> Result<(), anyhow::Error> {
    let mut conn = redis.get().await?;
    conn.del::<_, ()>(key).await?;
    Ok(())
}

// Invalidar pattern (ex: todas as chaves de um tenant)
pub async fn invalidate_pattern(redis: &deadpool_redis::Pool, pattern: &str) -> Result<(), anyhow::Error> {
    let mut conn = redis.get().await?;
    let keys: Vec<String> = redis::cmd("KEYS").arg(pattern).query_async(&mut conn).await?;
    if !keys.is_empty() {
        conn.del::<_, ()>(keys).await?;
    }
    Ok(())
}
```

## 6. Pub/Sub (Real-time Events)

```rust
// Publisher
pub async fn publish_event(
    redis: &deadpool_redis::Pool,
    channel: &str,
    event: &impl serde::Serialize,
) -> Result<(), anyhow::Error> {
    let mut conn = redis.get().await?;
    let payload = serde_json::to_string(event)?;
    conn.publish::<_, _, ()>(channel, &payload).await?;
    Ok(())
}

// Uso
publish_event(&state.redis, &format!("tenant:{}", tenant_id), &WebSocketEvent::DealMoved {
    deal_id, from_stage, to_stage
}).await?;

// Subscriber (background task)
pub async fn subscribe_tenant_events(redis_url: &str) {
    let client = redis::Client::open(redis_url).unwrap();
    let mut pubsub = client.get_async_pubsub().await.unwrap();
    pubsub.psubscribe("tenant:*").await.unwrap();

    let mut stream = pubsub.on_message();
    while let Some(msg) = stream.next().await {
        let channel: String = msg.get_channel().unwrap();
        let payload: String = msg.get_payload().unwrap();
        // Dispatch to WebSocket connections
    }
}
```

## 7. Session / Refresh Token Storage

```rust
// Refresh token: SET com TTL
pub async fn store_refresh_token(
    redis: &deadpool_redis::Pool,
    user_id: Uuid,
    token_hash: &str,
    ttl_seconds: u64,
) -> Result<(), anyhow::Error> {
    let mut conn = redis.get().await?;
    let key = format!("refresh:{}:{}", user_id, token_hash);
    conn.set_ex::<_, _, ()>(&key, "1", ttl_seconds).await?;
    Ok(())
}

// Revogar todas as sessões de um user
pub async fn revoke_all_sessions(
    redis: &deadpool_redis::Pool,
    user_id: Uuid,
) -> Result<(), anyhow::Error> {
    invalidate_pattern(redis, &format!("refresh:{}:*", user_id)).await
}
```

## 8. Job Queue (Simple)

```rust
// Enqueue job
pub async fn enqueue_job(
    redis: &deadpool_redis::Pool,
    queue: &str,
    job: &impl serde::Serialize,
) -> Result<(), anyhow::Error> {
    let mut conn = redis.get().await?;
    let payload = serde_json::to_string(job)?;
    conn.rpush::<_, _, ()>(queue, &payload).await?;
    Ok(())
}

// Worker (consume jobs)
pub async fn process_jobs(redis: &deadpool_redis::Pool, queue: &str) {
    loop {
        let mut conn = redis.get().await.unwrap();
        // BLPOP: blocking pop (espera job)
        let result: Option<(String, String)> = redis::cmd("BLPOP")
            .arg(queue)
            .arg(5)  // timeout 5s
            .query_async(&mut conn)
            .await
            .ok()
            .flatten();

        if let Some((_queue, payload)) = result {
            // Process job
            if let Err(e) = handle_job(&payload).await {
                tracing::error!("Job failed: {e}");
                // Re-enqueue com retry count no payload
            }
        }
    }
}
```

## 9. Rate Limiting

```rust
pub async fn check_rate_limit(
    redis: &deadpool_redis::Pool,
    key: &str,
    max_requests: u64,
    window_seconds: u64,
) -> Result<bool, anyhow::Error> {
    let mut conn = redis.get().await?;
    let current: u64 = conn.incr(key, 1).await?;
    if current == 1 {
        conn.expire::<_, ()>(key, window_seconds as i64).await?;
    }
    Ok(current <= max_requests)
}

// Uso: rate limit por tenant + API
let key = format!("ratelimit:{}:{}", tenant_id, "api");
if !check_rate_limit(&state.redis, &key, plan.max_api_calls, 60).await? {
    return Err(AppError::too_many_requests());
}
```

## Constraints

- ❌ NUNCA armazene dados críticos APENAS no Redis — sempre PostgreSQL + cache
- ❌ NUNCA use KEYS em produção com datasets grandes — use SCAN
- ❌ NUNCA crie conexão Redis por request — use pool
- ❌ NUNCA esqueça TTL em chaves de cache — Redis não é storage permanente

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

