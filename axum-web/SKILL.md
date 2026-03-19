---
name: Axum Web Framework
description: Architect, generate, and validate Axum web APIs enforcing typed extractors, Tower middleware composition, AppState patterns, IntoResponse error handling, graceful shutdown, WebSocket/SSE support, and modular router architecture.
---

# Axum — Diretrizes Sênior (v0.8+)

## 1. Princípio Zero: Ergonomia sem Mágica

Axum é um web framework **macro-free** baseado em Tower. Não há macros decorativas #[get], #[post]. Rotas são funções normais. Isso força clareza.

- **Tower é a fundação**: Cada middleware é um `Layer`, cada handler é um `Service`. Entenda Tower.
- **Extractors são o type system**: Request → Struct é feito via extractors tipados. Sem `serde_json::Value` genérico.
- **Micro-commits**: Um handler, um middleware, um extractor por vez. Não construa o app inteiro num prompt.
- **Consult `rust-lang` skill**: Esta skill complementa a skill `rust-lang`. SEMPRE leia ambas.
- **Clippy + cargo test**: Sempre rode `cargo clippy -- -D warnings && cargo test` antes de commitar.

## 2. Cargo.toml — Dependências Padrão

```toml
[dependencies]
axum = { version = "0.8", features = ["ws", "multipart"] }
tokio = { version = "1", features = ["full"] }
tower = "0.5"
tower-http = { version = "0.6", features = ["cors", "trace", "timeout", "compression-gzip", "limit"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter", "json"] }
thiserror = "2"
anyhow = "1"
uuid = { version = "1", features = ["v4", "serde"] }
chrono = { version = "0.4", features = ["serde"] }
sqlx = { version = "0.8", features = ["runtime-tokio", "postgres", "uuid", "chrono", "migrate"] }
dotenvy = "0.15"
tokio-util = "0.7"       # CancellationToken
validator = { version = "0.19", features = ["derive"] }
```

## 3. Estrutura de Projeto Obrigatória

```
src/
├── main.rs              # Entry: TcpListener + serve + graceful shutdown
├── lib.rs               # Re-exports públicos
├── config.rs            # Env vars → Config struct (dotenvy)
├── state.rs             # AppState (Arc<Inner>)
├── error.rs             # AppError + IntoResponse
├── routes/
│   ├── mod.rs           # api_router() — composição modular
│   ├── health.rs        # GET /health
│   └── tenants.rs       # /api/v1/tenants
├── handlers/            # Request handlers (finos, sem lógica)
├── services/            # Lógica de negócio
├── repositories/        # Data access (sqlx)
├── models/              # Entidades de domínio
├── dto/                 # Request/Response types (Serialize/Deserialize)
├── middleware/           # Auth, tenant isolation, logging
└── extractors/          # Custom Axum extractors
```

### Dogmas de Organização

- **Handlers são finos**: Extraem dados → chamam service → retornam response. Zero lógica de negócio.
- **Services são puros**: Recebem dados tipados → processam → retornam Result. Sem HTTP awareness.
- **Repositories isolam I/O**: Todo acesso ao banco vive aqui. Services nunca tocam `sqlx` diretamente.
- **DTOs separam layers**: `CreateTenantRequest` ≠ `Tenant` (model) ≠ `TenantResponse`. Nunca exponha models diretamente.

## 4. AppState — Shared State

```rust
// CERTO: State com Arc interno
use std::sync::Arc;
use sqlx::PgPool;

#[derive(Clone)]
pub struct AppState {
    inner: Arc<AppStateInner>,
}

struct AppStateInner {
    pub db: PgPool,
    pub config: Config,
    pub http_client: reqwest::Client,
}

impl AppState {
    pub fn new(db: PgPool, config: Config) -> Self {
        Self {
            inner: Arc::new(AppStateInner {
                db,
                config,
                http_client: reqwest::Client::new(),
            }),
        }
    }

    pub fn db(&self) -> &PgPool { &self.inner.db }
    pub fn config(&self) -> &Config { &self.inner.config }
}

// ERRADO: Arc<Mutex<>> para dados read-only
// ERRADO: Estado global com lazy_static
// ERRADO: Clone de PgPool raw sem wrapper
```

## 5. Routing — Modular e Composável

```rust
// CERTO: Router modular com nesting
use axum::{Router, routing::{get, post, delete}};

pub fn api_router() -> Router<AppState> {
    Router::new()
        .nest("/api/v1", v1_routes())
}

fn v1_routes() -> Router<AppState> {
    Router::new()
        .nest("/health", health_routes())
        .nest("/tenants", tenant_routes())
        .nest("/signals", signal_routes())
}

fn tenant_routes() -> Router<AppState> {
    Router::new()
        .route("/", get(list_tenants).post(create_tenant))
        .route("/{id}", get(get_tenant).patch(update_tenant).delete(delete_tenant))
        .route("/{id}/signals", get(list_tenant_signals))
}

// ERRADO: Todas as rotas no main.rs
// ERRADO: Hardcode de paths como strings com typos
```

### Rota com Path Parameters (v0.8+)

```rust
// CERTO: v0.8 usa {param} em vez de :param
.route("/{id}", get(get_tenant))
.route("/{tenant_id}/signals/{signal_id}", get(get_signal))

// ERRADO: Sintaxe antiga pré-0.8
.route("/:id", get(get_tenant))  // NÃO FUNCIONA em 0.8+
```

## 6. Handlers — Finos e Tipados

```rust
use axum::{
    extract::{State, Path, Query},
    http::StatusCode,
    Json,
};
use tracing::instrument;

#[instrument(skip(state))]
async fn list_tenants(
    State(state): State<AppState>,
    Query(pagination): Query<PaginationQuery>,
) -> Result<Json<PagedResponse<TenantResponse>>, AppError> {
    let tenants = state.tenant_service().list(&pagination).await?;
    Ok(Json(tenants))
}

async fn create_tenant(
    State(state): State<AppState>,
    Json(request): Json<CreateTenantRequest>,
) -> Result<(StatusCode, Json<TenantResponse>), AppError> {
    request.validate()?;  // validator crate
    let tenant = state.tenant_service().create(request).await?;
    Ok((StatusCode::CREATED, Json(tenant)))
}

async fn get_tenant(
    State(state): State<AppState>,
    Path(id): Path<uuid::Uuid>,
) -> Result<Json<TenantResponse>, AppError> {
    let tenant = state.tenant_service().find_by_id(id).await?;
    Ok(Json(tenant))
}

// ERRADO: Lógica de negócio no handler
async fn create_tenant(
    State(state): State<AppState>,
    Json(body): Json<serde_json::Value>,  // sem tipagem!
) -> impl IntoResponse {
    let name = body["name"].as_str().unwrap();  // PANIC!
    sqlx::query("INSERT INTO tenants ...").execute(state.db()).await.unwrap();
    "ok"  // sem status code, sem JSON
}
```

## 7. Extractors — Custom e Built-in

### Built-in Extractors

| Extractor | Fonte | Tipo |
|-----------|-------|------|
| `Path<T>` | URL path segments | `Path<Uuid>`, `Path<(String, u32)>` |
| `Query<T>` | Query string | `Query<PaginationQuery>` |
| `Json<T>` | Request body (JSON) | `Json<CreateRequest>` |
| `State<T>` | App state | `State<AppState>` |
| `HeaderMap` | All headers | `HeaderMap` |
| `Extension<T>` | Request extensions | `Extension<CurrentUser>` |
| `Request` | Raw request | `Request` |

### Custom Extractor (FromRequestParts)

```rust
// CERTO: Extractor customizado para autenticação
use axum::{
    extract::FromRequestParts,
    http::{StatusCode, request::Parts, header},
};

pub struct AuthUser {
    pub user_id: uuid::Uuid,
    pub tenant_id: uuid::Uuid,
    pub role: String,
}

impl<S> FromRequestParts<S> for AuthUser
where
    S: Send + Sync,
{
    type Rejection = AppError;

    async fn from_request_parts(parts: &mut Parts, _state: &S) -> Result<Self, Self::Rejection> {
        let token = parts.headers
            .get(header::AUTHORIZATION)
            .and_then(|v| v.to_str().ok())
            .and_then(|v| v.strip_prefix("Bearer "))
            .ok_or(AppError::Unauthorized("Missing token".into()))?;

        let claims = decode_jwt(token)
            .map_err(|_| AppError::Unauthorized("Invalid token".into()))?;

        Ok(AuthUser {
            user_id: claims.sub,
            tenant_id: claims.tenant_id,
            role: claims.role,
        })
    }
}

// Uso no handler — automático!
async fn list_signals(
    auth: AuthUser,  // extraído automaticamente
    State(state): State<AppState>,
) -> Result<Json<Vec<SignalResponse>>, AppError> {
    let signals = state.signal_service()
        .list_by_tenant(auth.tenant_id).await?;
    Ok(Json(signals))
}

// ERRADO: Verificar auth manualmente em cada handler
async fn list_signals(State(state): State<AppState>, headers: HeaderMap) -> ... {
    let token = headers.get("Authorization").unwrap();  // repetitivo + PANIC!
}
```

## 8. Error Handling — AppError + IntoResponse

```rust
use axum::{http::StatusCode, response::{IntoResponse, Response}, Json};
use thiserror::Error;

#[derive(Debug, Error)]
pub enum AppError {
    #[error("Validation: {0}")]
    Validation(String),

    #[error("Not found: {entity} {id}")]
    NotFound { entity: &'static str, id: String },

    #[error("Unauthorized: {0}")]
    Unauthorized(String),

    #[error("Forbidden")]
    Forbidden,

    #[error("Conflict: {0}")]
    Conflict(String),

    #[error("Database error")]
    Database(#[from] sqlx::Error),

    #[error("Internal: {0}")]
    Internal(#[from] anyhow::Error),
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, message) = match &self {
            AppError::Validation(msg) => (StatusCode::BAD_REQUEST, msg.clone()),
            AppError::NotFound { entity, id } => (
                StatusCode::NOT_FOUND,
                format!("{entity} with id {id} not found"),
            ),
            AppError::Unauthorized(msg) => (StatusCode::UNAUTHORIZED, msg.clone()),
            AppError::Forbidden => (StatusCode::FORBIDDEN, "Forbidden".into()),
            AppError::Conflict(msg) => (StatusCode::CONFLICT, msg.clone()),
            AppError::Database(e) => {
                tracing::error!("Database error: {e:?}");
                (StatusCode::INTERNAL_SERVER_ERROR, "Internal error".into())
            }
            AppError::Internal(e) => {
                tracing::error!("Internal error: {e:?}");
                (StatusCode::INTERNAL_SERVER_ERROR, "Internal error".into())
            }
        };

        let body = Json(serde_json::json!({
            "error": message,
            "status": status.as_u16(),
        }));

        (status, body).into_response()
    }
}

// ERRADO: String como tipo de erro
// ERRADO: Expor mensagens de database ao client
// ERRADO: Usar .unwrap() que causa panic no servidor inteiro
```

## 9. Middleware — from_fn e Tower Layers

### Middleware Simples (from_fn)

```rust
// CERTO: Middleware leve com from_fn
use axum::{
    middleware::{self, Next},
    extract::Request,
    response::Response,
    http::StatusCode,
};

async fn auth_middleware(
    mut req: Request,
    next: Next,
) -> Result<Response, StatusCode> {
    let token = req.headers()
        .get("Authorization")
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.strip_prefix("Bearer "));

    match token {
        Some(token) => {
            let user = verify_token(token).await
                .map_err(|_| StatusCode::UNAUTHORIZED)?;
            req.extensions_mut().insert(user);
            Ok(next.run(req).await)
        }
        None => Err(StatusCode::UNAUTHORIZED),
    }
}

// Aplicar middleware em rotas específicas
fn protected_routes() -> Router<AppState> {
    Router::new()
        .route("/tenants", get(list_tenants))
        .route_layer(middleware::from_fn(auth_middleware))
}

// ERRADO: Aplicar auth em /health
// ERRADO: Middleware que faz query no DB sem cache
```

### Tower Layers (tower-http)

```rust
use tower_http::{
    cors::{CorsLayer, Any},
    trace::TraceLayer,
    timeout::TimeoutLayer,
    compression::CompressionLayer,
    limit::RequestBodyLimitLayer,
};
use tower::ServiceBuilder;
use std::time::Duration;

fn app(state: AppState) -> Router {
    Router::new()
        .merge(api_router())
        .with_state(state)
        .layer(
            ServiceBuilder::new()
                .layer(TraceLayer::new_for_http())
                .layer(CompressionLayer::new())
                .layer(TimeoutLayer::new(Duration::from_secs(30)))
                .layer(RequestBodyLimitLayer::new(10 * 1024 * 1024)) // 10MB
                .layer(
                    CorsLayer::new()
                        .allow_origin(Any)
                        .allow_methods(Any)
                        .allow_headers(Any),
                ),
        )
}

// IMPORTANTE: Ordem dos layers = inversa da execução!
// O último .layer() é o primeiro a processar o request.
```

## 10. main.rs — Bootstrap e Graceful Shutdown

```rust
use tokio::net::TcpListener;
use tokio::signal;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Tracing
    tracing_subscriber::registry()
        .with(tracing_subscriber::EnvFilter::try_from_default_env()
            .unwrap_or_else(|_| "info,tower_http=debug".into()))
        .with(tracing_subscriber::fmt::layer())
        .init();

    // Config
    dotenvy::dotenv().ok();
    let config = Config::from_env()?;
    let db = sqlx::PgPool::connect(&config.database_url).await?;

    // Migrations
    sqlx::migrate!("./migrations").run(&db).await?;

    // State + App
    let state = AppState::new(db, config.clone());
    let app = app(state);

    // Serve
    let listener = TcpListener::bind(&config.bind_addr).await?;
    tracing::info!("🚀 Listening on {}", config.bind_addr);

    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await?;

    tracing::info!("Server shut down gracefully");
    Ok(())
}

async fn shutdown_signal() {
    let ctrl_c = async {
        signal::ctrl_c().await.expect("Failed to install Ctrl+C handler");
    };

    #[cfg(unix)]
    let terminate = async {
        signal::unix::signal(signal::unix::SignalKind::terminate())
            .expect("Failed to install SIGTERM handler")
            .recv()
            .await;
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => tracing::info!("Received SIGINT"),
        _ = terminate => tracing::info!("Received SIGTERM"),
    }
}

// ERRADO: axum::Server::bind (API antiga, pré 0.7)
// ERRADO: .unwrap() no serve
// ERRADO: Sem graceful shutdown (containers morrem sujo)
```

## 11. Validação de Input — validator crate

```rust
use validator::Validate;

#[derive(Debug, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct CreateTenantRequest {
    #[validate(length(min = 2, max = 100))]
    pub name: String,

    #[validate(length(min = 2, max = 50), regex(path = *SLUG_RE))]
    pub slug: String,

    #[validate(email)]
    pub owner_email: String,

    #[validate(length(min = 8, max = 128))]
    pub owner_password: String,
}

use once_cell::sync::Lazy;
use regex::Regex;

static SLUG_RE: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"^[a-z0-9]+(-[a-z0-9]+)*$").unwrap()
});

// Integração com AppError
impl From<validator::ValidationErrors> for AppError {
    fn from(err: validator::ValidationErrors) -> Self {
        AppError::Validation(err.to_string())
    }
}

// CERTO: No handler
async fn create_tenant(Json(req): Json<CreateTenantRequest>) -> Result<..., AppError> {
    req.validate()?;  // retorna 400 com detalhes
    // ...
}

// ERRADO: Validar manualmente com if/else
// ERRADO: Confiar no client e não validar server-side
```

## 12. WebSocket e SSE

```rust
// WebSocket
use axum::extract::ws::{WebSocket, WebSocketUpgrade, Message};

async fn ws_handler(
    ws: WebSocketUpgrade,
    State(state): State<AppState>,
) -> impl IntoResponse {
    ws.on_upgrade(|socket| handle_socket(socket, state))
}

async fn handle_socket(mut socket: WebSocket, state: AppState) {
    while let Some(Ok(msg)) = socket.recv().await {
        if let Message::Text(text) = msg {
            let reply = format!("Echo: {text}");
            if socket.send(Message::Text(reply)).await.is_err() {
                break;
            }
        }
    }
}

// SSE (Server-Sent Events)
use axum::response::sse::{Event, Sse};
use futures_util::stream::Stream;
use tokio_stream::StreamExt;

async fn sse_handler() -> Sse<impl Stream<Item = Result<Event, std::convert::Infallible>>> {
    let stream = tokio_stream::wrappers::IntervalStream::new(
        tokio::time::interval(Duration::from_secs(1))
    )
    .map(|_| Ok(Event::default().data("heartbeat")));

    Sse::new(stream)
}
```

## 13. Multi-Tenancy Pattern

```rust
// Middleware de isolamento por tenant
async fn tenant_isolation(
    auth: AuthUser,
    mut req: Request,
    next: Next,
) -> Result<Response, AppError> {
    // Insere tenant_id no request para todos os handlers downstream
    req.extensions_mut().insert(TenantContext {
        tenant_id: auth.tenant_id,
    });
    Ok(next.run(req).await)
}

#[derive(Clone)]
pub struct TenantContext {
    pub tenant_id: uuid::Uuid,
}

// Repository SEMPRE filtra por tenant
pub async fn list_signals(pool: &PgPool, tenant_id: Uuid) -> Result<Vec<Signal>, AppError> {
    let signals = sqlx::query_as!(
        Signal,
        "SELECT * FROM signals WHERE tenant_id = $1 ORDER BY created_at DESC",
        tenant_id
    )
    .fetch_all(pool)
    .await?;

    Ok(signals)
}

// ERRADO: Query sem WHERE tenant_id (data leak entre tenants!)
// ERRADO: Confiar em tenant_id vindo do client
```

## 14. Testing

```rust
// CERTO: Teste de integração com Axum TestClient ou tower::ServiceExt
#[cfg(test)]
mod tests {
    use super::*;
    use axum::body::Body;
    use axum::http::{Request, StatusCode};
    use tower::ServiceExt;  // oneshot

    #[tokio::test]
    async fn health_returns_200() {
        let app = app(test_state().await);

        let response = app
            .oneshot(Request::builder().uri("/health").body(Body::empty()).unwrap())
            .await
            .unwrap();

        assert_eq!(response.status(), StatusCode::OK);
    }

    #[tokio::test]
    async fn create_tenant_validates_input() {
        let app = app(test_state().await);

        let response = app
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri("/api/v1/tenants")
                    .header("Content-Type", "application/json")
                    .header("Authorization", "Bearer test-token")
                    .body(Body::from(r#"{"name": ""}"#))
                    .unwrap()
            )
            .await
            .unwrap();

        assert_eq!(response.status(), StatusCode::BAD_REQUEST);
    }
}

// ERRADO: Testes que dependem de servidor rodando
// ERRADO: Testes sem assertions significativas
```

## 15. Constraints — O que NUNCA Fazer

- ❌ NUNCA use `.unwrap()` em handlers — causa panic no server inteiro.
- ❌ NUNCA use `serde_json::Value` como request type — use DTOs tipados.
- ❌ NUNCA coloque lógica de negócio em handlers — delegue para services.
- ❌ NUNCA exponha models do banco como response — use DTOs de response.
- ❌ NUNCA use `Extension<T>` para state do app — use `State<T>` (type-safe).
- ❌ NUNCA faça queries SQL sem filtro de `tenant_id` em sistemas multi-tenant.
- ❌ NUNCA use `axum::Server::bind` — API removida em v0.7+. Use `axum::serve`.
- ❌ NUNCA use `:param` em rotas — v0.8+ usa `{param}`.
- ❌ NUNCA ignore graceful shutdown — containers precisam SIGTERM handling.
- ❌ NUNCA bloqueie o runtime — use `tokio::task::spawn_blocking` para CPU-bound work.

## Resumo do Escopo

Você atua quando gerando, validando ou debugando **Axum web APIs** — incluindo routing, handlers, extractors, middleware, state management, error handling, WebSocket, SSE, e multi-tenancy. Sempre complemente com a skill `rust-lang` para patterns de ownership, async Tokio, e SQLx.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

