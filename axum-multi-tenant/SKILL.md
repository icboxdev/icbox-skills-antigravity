---
name: Axum Multi-Tenant Architecture
description: Architect, enforce, and generate multi-tenant SaaS patterns for Axum/Rust. Covers shared-schema isolation with tenant_id, PostgreSQL Row-Level Security (RLS), middleware-based tenant context injection, scoped SQLx repositories, API key authentication (M2M and per-tenant), rate limiting per tenant, and data migration strategies.
---

# Axum Multi-Tenant — Diretrizes Sênior

## 1. Princípio Zero: Isolamento é Inegociável

Multi-tenancy significa que **um bug de isolamento é um breach de segurança**. Não existe "depois a gente isola". Todo código nasce isolado.

- **Skill complementar**: SEMPRE leia `axum-web` e `rust-lang` junto com esta skill.
- **Modelo padrão**: Shared Schema + `tenant_id` column + RLS. Não use schema-per-tenant salvo exigência regulatória.
- **Defense in depth**: RLS no PostgreSQL + `WHERE tenant_id` no application + middleware de contexto. Três camadas.
- **Zero trust no client**: O `tenant_id` SEMPRE vem do token/session no servidor. NUNCA do request body ou query param.

## 2. Estratégias de Isolamento — Quando Usar Qual

| Estratégia | Isolamento | Complexidade | Custo | Quando Usar |
|---|---|---|---|---|
| **Shared Schema + RLS** | Médio-Alto | Baixa | Baixo | SaaS padrão, < 10k tenants |
| **Schema-per-Tenant** | Alto | Média | Médio | Requisito regulatório (LGPD, HIPAA) |
| **Database-per-Tenant** | Máximo | Alta | Alto | Enterprise isolado, dados sensíveis |

### Dogma: Use Shared Schema + RLS como padrão

```sql
-- CERTO: Shared schema com tenant_id em TODA tabela
CREATE TABLE signals (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   UUID NOT NULL REFERENCES tenants(id),
    name        TEXT NOT NULL,
    value       DOUBLE PRECISION,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    
    -- Index composto OBRIGATÓRIO
    CONSTRAINT idx_signals_tenant UNIQUE (tenant_id, id)
);

CREATE INDEX idx_signals_tenant_created ON signals (tenant_id, created_at DESC);

-- ERRADO: Tabela sem tenant_id
CREATE TABLE signals (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL
    -- sem tenant_id = data leak garantido
);
```

## 3. PostgreSQL Row-Level Security (RLS)

### Setup Inicial

```sql
-- 1. Variável de sessão para tenant context
-- (setada pelo app a cada request)

-- 2. Habilitar RLS na tabela
ALTER TABLE signals ENABLE ROW LEVEL SECURITY;

-- 3. Policy: SELECT apenas dados do tenant
CREATE POLICY tenant_isolation_select ON signals
    FOR SELECT
    USING (tenant_id = current_setting('app.current_tenant_id')::uuid);

-- 4. Policy: INSERT vincula ao tenant atual
CREATE POLICY tenant_isolation_insert ON signals
    FOR INSERT
    WITH CHECK (tenant_id = current_setting('app.current_tenant_id')::uuid);

-- 5. Policy: UPDATE/DELETE apenas dados do tenant
CREATE POLICY tenant_isolation_update ON signals
    FOR UPDATE
    USING (tenant_id = current_setting('app.current_tenant_id')::uuid);

CREATE POLICY tenant_isolation_delete ON signals
    FOR DELETE
    USING (tenant_id = current_setting('app.current_tenant_id')::uuid);

-- 6. User da aplicação NÃO pode ser superuser (bypassa RLS!)
-- Use: CREATE ROLE app_user LOGIN PASSWORD '...';
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES TO app_user;
```

### Ativação por Request (SQLx)

```rust
// CERTO: Setar tenant context na conexão antes de qualquer query
use sqlx::PgPool;

pub async fn set_tenant_context(
    pool: &PgPool,
    tenant_id: uuid::Uuid,
) -> Result<sqlx::pool::PoolConnection<sqlx::Postgres>, sqlx::Error> {
    let mut conn = pool.acquire().await?;
    
    sqlx::query("SELECT set_config('app.current_tenant_id', $1, true)")
        .bind(tenant_id.to_string())
        .execute(&mut *conn)
        .await?;
    
    Ok(conn)
}

// ERRADO: Usar pool direto sem setar tenant context
// ERRADO: Setar com false (persiste além da transação!)
```

## 4. Tenant Context — Middleware Axum

### TenantContext Struct

```rust
// CERTO: Struct imutável com dados do tenant
#[derive(Debug, Clone)]
pub struct TenantContext {
    pub tenant_id: uuid::Uuid,
    pub tenant_slug: String,
    pub plan: TenantPlan,
}

#[derive(Debug, Clone)]
pub enum TenantPlan {
    Free,
    Starter,
    Pro,
    Enterprise,
}

impl TenantPlan {
    pub fn max_signals(&self) -> usize {
        match self {
            TenantPlan::Free => 10,
            TenantPlan::Starter => 100,
            TenantPlan::Pro => 1_000,
            TenantPlan::Enterprise => usize::MAX,
        }
    }

    pub fn max_users(&self) -> usize {
        match self {
            TenantPlan::Free => 2,
            TenantPlan::Starter => 10,
            TenantPlan::Pro => 50,
            TenantPlan::Enterprise => usize::MAX,
        }
    }
}

// ERRADO: tenant_id como String
// ERRADO: Sem informações de plano (não consegue enforçar limites)
```

### Middleware de Injeção de Contexto

```rust
use axum::{
    extract::{Request, State},
    http::StatusCode,
    middleware::Next,
    response::Response,
};

/// Middleware que extrai tenant do JWT e injeta TenantContext no request.
/// DEVE rodar APÓS auth middleware.
pub async fn tenant_context_middleware(
    State(state): State<AppState>,
    mut req: Request,
    next: Next,
) -> Result<Response, AppError> {
    // 1. Extrai AuthUser (já injetado pelo auth middleware)
    let auth_user = req.extensions()
        .get::<AuthUser>()
        .ok_or(AppError::Unauthorized("No auth context".into()))?
        .clone();

    // 2. Busca dados do tenant no banco (com cache!)
    let tenant = state.tenant_cache()
        .get_or_fetch(auth_user.tenant_id)
        .await
        .map_err(|_| AppError::Unauthorized("Tenant not found".into()))?;

    // 3. Verifica se tenant está ativo
    if tenant.status != TenantStatus::Active {
        return Err(AppError::Forbidden);
    }

    // 4. Injeta contexto no request
    req.extensions_mut().insert(TenantContext {
        tenant_id: tenant.id,
        tenant_slug: tenant.slug.clone(),
        plan: tenant.plan.clone(),
    });

    Ok(next.run(req).await)
}

// ERRADO: Buscar tenant do banco em CADA request sem cache
// ERRADO: Não verificar se tenant está ativo/suspenso
// ERRADO: Confiar no tenant_id do body/query param
```

### Extractor para Handlers

```rust
// CERTO: Custom extractor que pega TenantContext da Extension
use axum::extract::FromRequestParts;
use axum::http::request::Parts;

impl<S> FromRequestParts<S> for TenantContext
where
    S: Send + Sync,
{
    type Rejection = AppError;

    async fn from_request_parts(parts: &mut Parts, _state: &S) -> Result<Self, Self::Rejection> {
        parts.extensions
            .get::<TenantContext>()
            .cloned()
            .ok_or(AppError::Unauthorized("No tenant context".into()))
    }
}

// Uso no handler — limpo e type-safe
async fn list_signals(
    tenant: TenantContext,  // extraído automaticamente!
    State(state): State<AppState>,
    Query(params): Query<PaginationQuery>,
) -> Result<Json<PagedResponse<SignalResponse>>, AppError> {
    let signals = state.signal_service()
        .list(tenant.tenant_id, &params).await?;
    Ok(Json(signals))
}

// ERRADO: Passar tenant_id como Path param do client
// ERRADO: Extrair tenant_id do body do request
```

## 5. Router — Separação de Rotas Públicas vs Protegidas

```rust
pub fn api_router() -> Router<AppState> {
    Router::new()
        // Rotas públicas (sem auth/tenant)
        .nest("/api/v1/public", public_routes())
        // Rotas protegidas (com auth + tenant context)
        .nest("/api/v1", protected_routes())
        // Health check (sem middleware)
        .route("/health", get(health_check))
}

fn public_routes() -> Router<AppState> {
    Router::new()
        .route("/auth/login", post(login))
        .route("/auth/register", post(register))
}

fn protected_routes() -> Router<AppState> {
    Router::new()
        .nest("/signals", signal_routes())
        .nest("/events", event_routes())
        .nest("/settings", settings_routes())
        // Middleware stack: auth PRIMEIRO, tenant context DEPOIS
        .route_layer(middleware::from_fn(tenant_context_middleware))
        .route_layer(middleware::from_fn(auth_middleware))
}

// M2M routes (API key auth, sem tenant context do JWT)
fn m2m_routes() -> Router<AppState> {
    Router::new()
        .nest("/api/v1/m2m", Router::new()
            .route("/provision", post(provision_tenant))
            .route("/ingest", post(ingest_data))
            .route_layer(middleware::from_fn(api_key_auth_middleware))
        )
}

// IMPORTANTE: route_layer executa de BAIXO para CIMA!
// auth_middleware roda ANTES de tenant_context_middleware
```

## 6. Repositórios — SEMPRE Scoped por Tenant

```rust
// CERTO: Repository que OBRIGA tenant_id em toda operação
pub struct SignalRepository;

impl SignalRepository {
    pub async fn find_all(
        pool: &PgPool,
        tenant_id: Uuid,
        params: &PaginationQuery,
    ) -> Result<Vec<Signal>, AppError> {
        let signals = sqlx::query_as!(
            Signal,
            r#"
            SELECT id, tenant_id, name, value, created_at
            FROM signals
            WHERE tenant_id = $1
            ORDER BY created_at DESC
            LIMIT $2 OFFSET $3
            "#,
            tenant_id,
            params.limit() as i64,
            params.offset() as i64,
        )
        .fetch_all(pool)
        .await?;

        Ok(signals)
    }

    pub async fn find_by_id(
        pool: &PgPool,
        tenant_id: Uuid,
        signal_id: Uuid,
    ) -> Result<Option<Signal>, AppError> {
        let signal = sqlx::query_as!(
            Signal,
            r#"
            SELECT id, tenant_id, name, value, created_at
            FROM signals
            WHERE tenant_id = $1 AND id = $2
            "#,
            tenant_id,
            signal_id,
        )
        .fetch_optional(pool)
        .await?;

        Ok(signal)
    }

    pub async fn create(
        pool: &PgPool,
        tenant_id: Uuid,
        req: &CreateSignalRequest,
    ) -> Result<Signal, AppError> {
        let signal = sqlx::query_as!(
            Signal,
            r#"
            INSERT INTO signals (tenant_id, name, value)
            VALUES ($1, $2, $3)
            RETURNING id, tenant_id, name, value, created_at
            "#,
            tenant_id,
            req.name,
            req.value,
        )
        .fetch_one(pool)
        .await?;

        Ok(signal)
    }

    pub async fn delete(
        pool: &PgPool,
        tenant_id: Uuid,
        signal_id: Uuid,
    ) -> Result<bool, AppError> {
        let result = sqlx::query!(
            "DELETE FROM signals WHERE tenant_id = $1 AND id = $2",
            tenant_id,
            signal_id,
        )
        .execute(pool)
        .await?;

        Ok(result.rows_affected() > 0)
    }
}

// ERRADO: Método sem tenant_id
pub async fn find_by_id(pool: &PgPool, id: Uuid) -> Result<Signal, AppError> {
    // SEM tenant_id = data leak cross-tenant!
    sqlx::query_as!(Signal, "SELECT * FROM signals WHERE id = $1", id)
        .fetch_one(pool).await.map_err(Into::into)
}
```

## 7. Autenticação M2M (Machine-to-Machine)

```rust
// API Key authentication para comunicação entre serviços
use subtle::ConstantTimeEq;  // timing-safe comparison

pub async fn api_key_auth_middleware(
    State(state): State<AppState>,
    mut req: Request,
    next: Next,
) -> Result<Response, AppError> {
    let api_key = req.headers()
        .get("X-API-Key")
        .or_else(|| req.headers().get("X-Master-Key"))
        .and_then(|v| v.to_str().ok())
        .ok_or(AppError::Unauthorized("Missing API key".into()))?;

    // Timing-safe comparison contra master key
    let master_key = state.config().master_api_key.as_bytes();
    let provided_key = api_key.as_bytes();

    if master_key.len() != provided_key.len()
        || master_key.ct_eq(provided_key).unwrap_u8() != 1
    {
        return Err(AppError::Unauthorized("Invalid API key".into()));
    }

    // M2M: tenant_id vem do body/header, não do JWT
    if let Some(tenant_header) = req.headers().get("X-Tenant-Id") {
        let tenant_id: Uuid = tenant_header.to_str()
            .map_err(|_| AppError::Validation("Invalid X-Tenant-Id".into()))?
            .parse()
            .map_err(|_| AppError::Validation("X-Tenant-Id must be UUID".into()))?;

        req.extensions_mut().insert(M2MContext { tenant_id });
    }

    Ok(next.run(req).await)
}

#[derive(Debug, Clone)]
pub struct M2MContext {
    pub tenant_id: Uuid,
}

// ERRADO: Comparação simples de string (timing attack!)
if api_key == state.config().master_key { ... }

// ERRADO: Sem logging de tentativas falhas
```

## 8. Tenant Cache — Evitar N+1 no Banco

```rust
use std::sync::Arc;
use tokio::sync::RwLock;
use std::collections::HashMap;
use std::time::{Duration, Instant};

#[derive(Clone)]
pub struct TenantCache {
    inner: Arc<RwLock<HashMap<Uuid, CachedTenant>>>,
    pool: PgPool,
    ttl: Duration,
}

struct CachedTenant {
    tenant: TenantInfo,
    cached_at: Instant,
}

impl TenantCache {
    pub fn new(pool: PgPool, ttl: Duration) -> Self {
        Self {
            inner: Arc::new(RwLock::new(HashMap::new())),
            pool,
            ttl,
        }
    }

    pub async fn get_or_fetch(&self, tenant_id: Uuid) -> Result<TenantInfo, AppError> {
        // 1. Check cache (read lock)
        {
            let cache = self.inner.read().await;
            if let Some(cached) = cache.get(&tenant_id) {
                if cached.cached_at.elapsed() < self.ttl {
                    return Ok(cached.tenant.clone());
                }
            }
        }

        // 2. Cache miss/expired → fetch from DB
        let tenant = sqlx::query_as!(
            TenantInfo,
            "SELECT id, slug, status, plan FROM tenants WHERE id = $1",
            tenant_id,
        )
        .fetch_optional(&self.pool)
        .await?
        .ok_or(AppError::NotFound {
            entity: "Tenant",
            id: tenant_id.to_string(),
        })?;

        // 3. Update cache (write lock)
        {
            let mut cache = self.inner.write().await;
            cache.insert(tenant_id, CachedTenant {
                tenant: tenant.clone(),
                cached_at: Instant::now(),
            });
        }

        Ok(tenant)
    }

    pub async fn invalidate(&self, tenant_id: Uuid) {
        let mut cache = self.inner.write().await;
        cache.remove(&tenant_id);
    }
}

// ERRADO: Sem cache (query SELECT tenant em cada request)
// ERRADO: Cache sem TTL (dados stale forever)
// ERRADO: std::sync::Mutex com async (deadlock!)
```

## 9. Rate Limiting Per-Tenant

```rust
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use std::time::Instant;

#[derive(Clone)]
pub struct TenantRateLimiter {
    limits: Arc<RwLock<HashMap<Uuid, TenantBucket>>>,
}

struct TenantBucket {
    tokens: u32,
    last_refill: Instant,
    max_tokens: u32,
    refill_rate: u32,  // tokens per second
}

impl TenantRateLimiter {
    pub async fn check(&self, tenant_id: Uuid, plan: &TenantPlan) -> Result<(), AppError> {
        let (max, rate) = match plan {
            TenantPlan::Free => (10, 1),          // 10 req burst, 1/sec
            TenantPlan::Starter => (50, 10),      // 50 req burst, 10/sec
            TenantPlan::Pro => (200, 50),         // 200 req burst, 50/sec
            TenantPlan::Enterprise => (1000, 200), // 1000 req burst, 200/sec
        };

        let mut limits = self.limits.write().await;
        let bucket = limits.entry(tenant_id).or_insert(TenantBucket {
            tokens: max,
            last_refill: Instant::now(),
            max_tokens: max,
            refill_rate: rate,
        });

        // Token bucket refill
        let elapsed = bucket.last_refill.elapsed().as_secs() as u32;
        if elapsed > 0 {
            bucket.tokens = (bucket.tokens + elapsed * bucket.refill_rate).min(bucket.max_tokens);
            bucket.last_refill = Instant::now();
        }

        if bucket.tokens == 0 {
            return Err(AppError::TooManyRequests);
        }

        bucket.tokens -= 1;
        Ok(())
    }
}

// Middleware
pub async fn rate_limit_middleware(
    State(state): State<AppState>,
    req: Request,
    next: Next,
) -> Result<Response, AppError> {
    if let Some(tenant) = req.extensions().get::<TenantContext>() {
        state.rate_limiter().check(tenant.tenant_id, &tenant.plan).await?;
    }
    Ok(next.run(req).await)
}
```

## 10. Migrations — Multi-Tenant Aware

```sql
-- REGRA: Toda tabela nova DEVE ter tenant_id
-- migrations/20260315_create_readings.sql

CREATE TABLE readings (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    signal_id   UUID NOT NULL REFERENCES signals(id) ON DELETE CASCADE,
    value       DOUBLE PRECISION NOT NULL,
    timestamp   TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- FK composta garante integridade cross-tenant
    FOREIGN KEY (tenant_id, signal_id) 
        REFERENCES signals(tenant_id, id)
);

-- Index para queries por tenant + tempo (OBRIGATÓRIO)
CREATE INDEX idx_readings_tenant_time 
    ON readings (tenant_id, timestamp DESC);

-- RLS
ALTER TABLE readings ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON readings
    FOR ALL
    USING (tenant_id = current_setting('app.current_tenant_id')::uuid)
    WITH CHECK (tenant_id = current_setting('app.current_tenant_id')::uuid);
```

## 11. Testing Multi-Tenant

```rust
#[cfg(test)]
mod tests {
    use super::*;

    /// Helper: cria 2 tenants e verifica isolamento
    #[tokio::test]
    async fn signals_are_tenant_isolated() {
        let pool = test_pool().await;
        let tenant_a = create_test_tenant(&pool, "Tenant A").await;
        let tenant_b = create_test_tenant(&pool, "Tenant B").await;

        // Cria signal para tenant A
        let signal = SignalRepository::create(
            &pool, tenant_a.id,
            &CreateSignalRequest { name: "temp".into(), value: Some(25.0) },
        ).await.unwrap();

        // Tenant A vê o signal
        let found = SignalRepository::find_by_id(&pool, tenant_a.id, signal.id)
            .await.unwrap();
        assert!(found.is_some());

        // Tenant B NÃO vê o signal (isolamento!)
        let not_found = SignalRepository::find_by_id(&pool, tenant_b.id, signal.id)
            .await.unwrap();
        assert!(not_found.is_none(), "CRITICAL: Cross-tenant data leak!");
    }

    #[tokio::test]
    async fn suspended_tenant_gets_403() {
        let app = app(test_state().await);
        let token = create_suspended_tenant_token().await;

        let response = app
            .oneshot(
                Request::builder()
                    .uri("/api/v1/signals")
                    .header("Authorization", format!("Bearer {token}"))
                    .body(Body::empty())
                    .unwrap()
            )
            .await
            .unwrap();

        assert_eq!(response.status(), StatusCode::FORBIDDEN);
    }
}
```

## 12. Constraints — O que NUNCA Fazer

- ❌ NUNCA aceite `tenant_id` do client (body, query, path) para autorização — SEMPRE do token/session.
- ❌ NUNCA crie tabela sem coluna `tenant_id` — toda entidade pertence a um tenant.
- ❌ NUNCA faça `SELECT` sem `WHERE tenant_id` — mesmo com RLS ativo (defense in depth).
- ❌ NUNCA use `DELETE FROM tabela WHERE id = $1` sem `AND tenant_id` — race condition cross-tenant.
- ❌ NUNCA compare API keys com `==` — use `subtle::ConstantTimeEq` (timing-safe).
- ❌ NUNCA use `superuser` no PostgreSQL para o app — superuser bypassa RLS completamente.
- ❌ NUNCA cache dados de tenant sem TTL — tenants suspensos ficam ativos no cache forever.
- ❌ NUNCA exponha `tenant_id` interno nas URLs públicas — use `slug` para URLs, `UUID` interno.
- ❌ NUNCA permita um tenant acessar dados de outro via foreign key sem validação de ownership.
- ❌ NUNCA implemente rate limiting global — use per-tenant baseado no plano.

## Resumo do Escopo

Você atua quando arquitetando, gerando ou debugando **isolamento multi-tenant** em APIs Axum — incluindo middleware de contexto, repositórios scoped, RLS no PostgreSQL, cache de tenant, rate limiting por plano, autenticação M2M, e testes de isolamento cross-tenant. Complemente com `axum-web` (routing/handlers) e `rust-lang` (ownership/async).

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

