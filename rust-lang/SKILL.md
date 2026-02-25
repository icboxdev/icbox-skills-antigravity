---
name: Rust Systems Programming
description: Validate, architect, and generate Rust applications enforcing ownership safety, zero-cost abstractions, trait-based polymorphism, error handling with thiserror/anyhow, async patterns with Tokio, web APIs with Axum, serialization with Serde, and systems-level best practices.
---

# Rust — Diretrizes Sênior

## 1. Princípio Zero: Safety & Context Limits

- **O compilador é seu aliado**: Se o borrow checker reclamar, você provavelmente está fazendo algo inseguro. Corrija a lógica, não silenci o compilador.
- **Zero `unsafe` sem justificativa**: Todo bloco `unsafe` DEVE ter um comentário `// SAFETY:` explicando por que é seguro.
- **Micro-commits**: Uma trait, um módulo, um handler por vez. Não construa um crate inteiro em um prompt.
- **Externalize Contexto**: Para refatorações complexas, crie/atualize `AI.md` antes de codar.
- **Clippy é lei**: `cargo clippy -- -D warnings` deve passar sem erros. Sempre.

## 2. Cargo.toml & Toolchain Obrigatória

```toml
[package]
name = "my-project"
version = "0.1.0"
edition = "2024"          # Sempre a edition mais recente
rust-version = "1.85.0"   # MSRV explícito

[lints.rust]
unsafe_code = "forbid"     # Proíbe unsafe por padrão

[lints.clippy]
all = { level = "deny" }
pedantic = { level = "warn" }
nursery = { level = "warn" }

[profile.release]
lto = true                 # Link-Time Optimization
strip = true               # Remove símbolos debug
codegen-units = 1           # Otimização máxima
panic = "abort"             # Menor binário
```

### Comandos Obrigatórios Pré-Commit

```bash
cargo fmt --check           # Formatação
cargo clippy -- -D warnings # Lints
cargo test                  # Testes
cargo build --release       # Build release funciona
```

## 3. Ownership, Borrowing & Lifetimes

### Dogmas Inegociáveis

- SEMPRE prefira **borrowing** (`&T`, `&mut T`) sobre ownership quando não precisa consumir o valor.
- SEMPRE prefira **`&str`** sobre `String` em parâmetros de função (aceita ambos).
- SEMPRE use **`Clone` conscientemente** — clone tem custo. Prefira referências.
- SEMPRE anote **lifetimes explícitos** quando o compilador pedir — nunca use `'static` como escape.
- NUNCA use `Rc<RefCell<T>>` quando `&mut T` basta — complexidade desnecessária.
- NUNCA use `.unwrap()` em código de produção — use `?`, `.expect("msg")` ou pattern match.

```rust
// CERTO: Borrowing eficiente, aceita &str e String
fn greet(name: &str) -> String {
    format!("Olá, {name}!")
}

// Chamadas válidas:
greet("Ideilson");          // &str
greet(&my_string);          // &String → coerce para &str

// ERRADO: Clona sem necessidade
fn greet(name: String) -> String {  // força clone do caller!
    format!("Olá, {name}!")
}
```

```rust
// CERTO: Lifetime explícito quando necessário
fn longest<'a>(x: &'a str, y: &'a str) -> &'a str {
    if x.len() > y.len() { x } else { y }
}

// ERRADO: 'static como escape preguiçoso
fn longest(x: &str, y: &str) -> &'static str {
    // Impossível retornar referência a dados locais como 'static!
    Box::leak(format!("{x}{y}").into_boxed_str())  // memory leak!
}
```

## 4. Error Handling — `thiserror` + `anyhow`

### Regra de Ouro

- **Libraries** usam `thiserror` → erros tipados, composáveis.
- **Applications** usam `anyhow` → erros ergonômicos com contexto.
- NUNCA use `.unwrap()` em produção. NUNCA.
- SEMPRE use o operador `?` para propagação de erros.
- SEMPRE implemente `Display` e `Error` via `thiserror` em libs.

```rust
// CERTO: thiserror para erros tipados (biblioteca/módulo)
use thiserror::Error;

#[derive(Debug, Error)]
pub enum AppError {
    #[error("Validation error: {0}")]
    Validation(String),

    #[error("Entity not found: {entity} with id {id}")]
    NotFound { entity: &'static str, id: String },

    #[error("Unauthorized: {0}")]
    Unauthorized(String),

    #[error("Database error")]
    Database(#[from] sqlx::Error),

    #[error("IO error")]
    Io(#[from] std::io::Error),

    #[error("External service error: {0}")]
    External(String),
}

// CERTO: anyhow para aplicações (main, scripts, CLIs)
use anyhow::{Context, Result};

async fn load_config() -> Result<Config> {
    let content = tokio::fs::read_to_string("config.toml")
        .await
        .context("Failed to read config.toml")?;

    let config: Config = toml::from_str(&content)
        .context("Failed to parse config.toml")?;

    Ok(config)
}

// ERRADO: String como erro
fn do_thing() -> Result<(), String> {
    Err("deu ruim".to_string())  // sem tipo, sem contexto, sem stack
}

// ERRADO: unwrap em produção
let file = std::fs::read_to_string("data.json").unwrap();  // PANIC!
```

## 5. Structs, Enums & Traits

### Structs — Modelagem de Dados

```rust
// CERTO: Struct com derive essenciais + builders
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Project {
    pub id: Uuid,
    pub name: String,
    pub description: Option<String>,
    pub status: ProjectStatus,
    pub owner_id: Uuid,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateProjectRequest {
    pub name: String,
    pub description: Option<String>,
    pub project_type: ProjectType,
}

// ERRADO: Campos públicos sem derive, sem tipagem forte
pub struct Project {
    pub name: String,
    pub status: String,         // string genérica em vez de enum!
    pub created_at: String,     // string em vez de DateTime!
}
```

### Enums — Algebraic Data Types

```rust
// CERTO: Enum rico com dados associados
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ProjectStatus {
    Draft,
    Active,
    Paused { reason: String },
    Completed { completed_at: DateTime<Utc> },
    Archived,
}

// CERTO: Pattern matching exaustivo
fn status_label(status: &ProjectStatus) -> &str {
    match status {
        ProjectStatus::Draft => "Rascunho",
        ProjectStatus::Active => "Ativo",
        ProjectStatus::Paused { .. } => "Pausado",
        ProjectStatus::Completed { .. } => "Concluído",
        ProjectStatus::Archived => "Arquivado",
    }
}

// ERRADO: String constants
const STATUS_DRAFT: &str = "draft";
const STATUS_ACTIVE: &str = "active";  // sem type safety!
```

### Traits — Polimorfismo Zero-Cost

```rust
// CERTO: Trait com associated types
pub trait Repository {
    type Entity;
    type Error;

    async fn find_by_id(&self, id: Uuid) -> Result<Option<Self::Entity>, Self::Error>;
    async fn create(&self, entity: &Self::Entity) -> Result<Self::Entity, Self::Error>;
    async fn delete(&self, id: Uuid) -> Result<(), Self::Error>;
}

// Implementação concreta
pub struct PostgresProjectRepo {
    pool: PgPool,
}

impl Repository for PostgresProjectRepo {
    type Entity = Project;
    type Error = AppError;

    async fn find_by_id(&self, id: Uuid) -> Result<Option<Project>, AppError> {
        let project = sqlx::query_as!(
            Project,
            "SELECT * FROM projects WHERE id = $1",
            id
        )
        .fetch_optional(&self.pool)
        .await?;
        Ok(project)
    }

    // ...
}

// ERRADO: Trait objects desnecessários quando generics bastam
fn process(repo: &dyn Repository) { ... }  // dynamic dispatch sem necessidade
// CERTO: Generics (monomorphization, zero-cost)
fn process<R: Repository>(repo: &R) { ... }
```

## 6. Async — Tokio Runtime

### Dogmas

- SEMPRE use **Tokio** como runtime async padrão.
- SEMPRE use **`tokio::spawn`** para tasks concorrentes — nunca `std::thread::spawn` para I/O.
- SEMPRE use **`tokio::select!`** para racing entre futures.
- SEMPRE passe **`CancellationToken`** para tasks longas — graceful shutdown.
- NUNCA bloqueie o runtime com operações síncronas — use `tokio::task::spawn_blocking`.
- NUNCA use `std::sync::Mutex` com async — use `tokio::sync::Mutex` ou `RwLock`.

```rust
// CERTO: Async com Tokio
use tokio::sync::RwLock;
use std::sync::Arc;

struct AppState {
    cache: Arc<RwLock<HashMap<String, String>>>,
}

async fn get_cached(state: &AppState, key: &str) -> Option<String> {
    let cache = state.cache.read().await;
    cache.get(key).cloned()
}

// CERTO: spawn_blocking para CPU-bound work
async fn hash_password(password: String) -> Result<String, AppError> {
    tokio::task::spawn_blocking(move || {
        bcrypt::hash(password, 12)
            .map_err(|e| AppError::External(e.to_string()))
    })
    .await
    .map_err(|e| AppError::External(e.to_string()))?
}

// ERRADO: Bloqueando o runtime
async fn hash_password(password: &str) -> String {
    bcrypt::hash(password, 12).unwrap()  // bloqueia o runtime inteiro!
}
```

## 7. Web APIs — Axum

### Estrutura de Projeto

```
src/
├── main.rs              # Entry + server bootstrap
├── lib.rs               # Re-exports
├── config.rs            # Environment configuration
├── state.rs             # AppState (shared state)
├── error.rs             # AppError + IntoResponse
├── routes/
│   ├── mod.rs           # Router composition
│   ├── health.rs        # GET /health
│   ├── projects.rs      # /api/v1/projects
│   └── auth.rs          # /api/v1/auth
├── handlers/            # Request handlers (thin)
├── services/            # Business logic
├── repositories/        # Data access (sqlx)
├── models/              # Domain entities
├── dto/                 # Request/Response types
├── middleware/           # Auth, logging, CORS
└── extractors/          # Custom Axum extractors
```

### Router & Handlers

```rust
// CERTO: Router modular com state e Tracing
use axum::{
    Router, Json,
    extract::{State, Path, Query},
    http::StatusCode,
    routing::{get, post, delete},
};
use tracing::instrument;

pub fn project_routes() -> Router<AppState> {
    Router::new()
        .route("/", get(list_projects).post(create_project))
        .route("/{id}", get(get_project).delete(delete_project))
}

#[instrument(skip(state))]
async fn list_projects(
    State(state): State<AppState>,
    Query(pagination): Query<PaginationQuery>,
) -> Result<Json<PagedResponse<ProjectResponse>>, AppError> {
    let projects = state.project_service.list(pagination).await?;
    Ok(Json(projects))
}

async fn create_project(
    State(state): State<AppState>,
    Json(request): Json<CreateProjectRequest>,
) -> Result<(StatusCode, Json<ProjectResponse>), AppError> {
    let project = state.project_service.create(request).await?;
    Ok((StatusCode::CREATED, Json(project)))
}

// ERRADO: Handler gigante com lógica de negócio
async fn create_project(
    State(state): State<AppState>,
    Json(body): Json<serde_json::Value>,  // sem tipagem!
) -> impl IntoResponse {
    let name = body["name"].as_str().unwrap();  // PANIC!
    sqlx::query("INSERT INTO projects ...").execute(&state.pool).await.unwrap();
    "ok"  // sem status code, sem JSON estruturado
}
```

### Error → HTTP Response

```rust
// CERTO: AppError implementa IntoResponse
impl IntoResponse for AppError {
    fn into_response(self) -> axum::response::Response {
        let (status, message) = match &self {
            AppError::Validation(msg) => (StatusCode::BAD_REQUEST, msg.clone()),
            AppError::NotFound { entity, id } => (
                StatusCode::NOT_FOUND,
                format!("{entity} with id {id} not found"),
            ),
            AppError::Unauthorized(msg) => (StatusCode::UNAUTHORIZED, msg.clone()),
            AppError::Database(_) => (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Internal server error".to_string(),
            ),
            AppError::Io(_) => (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Internal server error".to_string(),
            ),
            AppError::External(msg) => (StatusCode::BAD_GATEWAY, msg.clone()),
        };

        let body = Json(serde_json::json!({
            "error": message,
            "status": status.as_u16(),
        }));

        (status, body).into_response()
    }
}
```

## 8. Serialization — Serde

```rust
// CERTO: Serde com rename, skip, default
#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ProjectResponse {
    pub id: Uuid,
    pub name: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    pub status: ProjectStatus,
    pub created_at: DateTime<Utc>,

    #[serde(skip)]
    pub internal_notes: String,  // nunca serializado
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PaginationQuery {
    #[serde(default = "default_page")]
    pub page: u32,
    #[serde(default = "default_page_size")]
    pub page_size: u32,
}

fn default_page() -> u32 { 1 }
fn default_page_size() -> u32 { 20 }

// ERRADO: Sem serde attributes, expõe tudo
#[derive(Serialize)]
pub struct Project {
    pub password_hash: String,  // vaza hash de senha!
    pub internal_id: i64,       // expõe ID interno!
}
```

## 9. Database — SQLx (Compile-Time Checked)

```rust
// CERTO: SQLx com query verificada em compile-time
pub async fn find_by_id(pool: &PgPool, id: Uuid) -> Result<Option<Project>, AppError> {
    let project = sqlx::query_as!(
        Project,
        r#"
        SELECT id, name, description, status as "status: ProjectStatus",
               owner_id, created_at, updated_at
        FROM projects
        WHERE id = $1
        "#,
        id
    )
    .fetch_optional(pool)
    .await?;

    Ok(project)
}

// CERTO: Transações
pub async fn create_with_members(
    pool: &PgPool,
    project: &CreateProjectRequest,
    member_ids: &[Uuid],
) -> Result<Project, AppError> {
    let mut tx = pool.begin().await?;

    let project = sqlx::query_as!(
        Project,
        "INSERT INTO projects (name, description) VALUES ($1, $2) RETURNING *",
        project.name,
        project.description
    )
    .fetch_one(&mut *tx)
    .await?;

    for member_id in member_ids {
        sqlx::query!(
            "INSERT INTO project_members (project_id, user_id) VALUES ($1, $2)",
            project.id,
            member_id
        )
        .execute(&mut *tx)
        .await?;
    }

    tx.commit().await?;
    Ok(project)
}

// ERRADO: String interpolation em SQL
let query = format!("SELECT * FROM projects WHERE name = '{}'", name); // SQL INJECTION!
```

## 10. Testing

```rust
// CERTO: Testes com #[tokio::test] e assertions claras
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn status_label_returns_correct_text() {
        assert_eq!(status_label(&ProjectStatus::Draft), "Rascunho");
        assert_eq!(status_label(&ProjectStatus::Active), "Ativo");
    }

    #[tokio::test]
    async fn create_project_validates_name() {
        let service = ProjectService::new(MockRepo::new());
        let request = CreateProjectRequest {
            name: "".to_string(),
            description: None,
            project_type: ProjectType::Internal,
        };

        let result = service.create(request).await;

        assert!(result.is_err());
        assert!(matches!(result.unwrap_err(), AppError::Validation(_)));
    }
}

// ERRADO: Sem assertions significativas
#[test]
fn it_works() {
    let x = 2 + 2;
    assert!(x > 0);  // assertion inútil
}
```

## 11. Docker — Multi-Stage Build

```dockerfile
# CERTO: Multi-stage para Rust
FROM rust:1.85-slim AS builder
WORKDIR /app
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release && rm -rf src  # cache de deps

COPY src/ src/
RUN touch src/main.rs && cargo build --release

FROM debian:bookworm-slim AS runtime
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*
RUN adduser --system --group appuser
USER appuser
WORKDIR /app
COPY --from=builder /app/target/release/my-project .
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s CMD curl -f http://localhost:8080/health || exit 1
ENTRYPOINT ["./my-project"]

# ERRADO: Imagem de build em produção
FROM rust:latest
COPY . .
RUN cargo run  # 1.5GB de imagem com toolchain inteira!
```

## 12. Ferramentas Essenciais (2025)

| Categoria       | Ferramenta                   | Alternativa             |
| --------------- | ---------------------------- | ----------------------- |
| **Runtime**     | Tokio                        | async-std, smol         |
| **Web**         | Axum                         | Actix-web, Rocket, Warp |
| **ORM/DB**      | SQLx (compile-time)          | Diesel, SeaORM          |
| **Serializer**  | Serde                        | —                       |
| **Error**       | thiserror + anyhow           | miette, eyre            |
| **Logging**     | tracing + tracing-subscriber | log + env_logger        |
| **Config**      | config-rs                    | dotenvy, envy           |
| **Validation**  | validator (derive)           | garde                   |
| **Testing**     | cargo test + mockall         | rstest, proptest        |
| **HTTP Client** | reqwest                      | ureq, hyper             |
| **CLI**         | clap (derive)                | argh                    |
| **Crypto**      | argon2 / bcrypt              | ring, rustls            |
| **Container**   | Docker (debian-slim)         | Alpine (musl)           |
| **CI/CD**       | GitHub Actions + cargo-deny  | GitLab CI               |

## 13. Performance & Idiomas

- SEMPRE prefira **iterators** sobre loops indexados — zero-cost abstractions.
- SEMPRE use **`Cow<'_, str>`** quando precisa aceitar owned e borrowed.
- SEMPRE use **`#[inline]`** com moderação — o compilador geralmente sabe melhor.
- SEMPRE use **`Arc<T>`** para shared ownership entre threads, não `Rc<T>`.
- NUNCA aloque desnecessariamente — `&[u8]` sobre `Vec<u8>` quando possível.
- NUNCA use `collect::<Vec<_>>()` intermediário quando pode encadear iterators.

```rust
// CERTO: Iterator chaining
let active_names: Vec<&str> = projects
    .iter()
    .filter(|p| matches!(p.status, ProjectStatus::Active))
    .map(|p| p.name.as_str())
    .collect();

// ERRADO: Collect intermediário + loop indexado
let filtered: Vec<&Project> = projects.iter().filter(|p| p.is_active()).collect();
let mut names = Vec::new();
for i in 0..filtered.len() {
    names.push(filtered[i].name.as_str());
}
```

## Resumo do Escopo

Você atua quando orquestrando, debugando ou gerando Rust — incluindo CLIs, APIs (Axum), sistemas (Tokio), libraries e Tauri backends. Sempre valide com `cargo clippy -- -D warnings && cargo test` antes de commitar.
