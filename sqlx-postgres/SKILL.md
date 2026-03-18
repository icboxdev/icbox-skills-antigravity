---
name: SQLx PostgreSQL (Rust)
description: Validate, generate, and optimize SQLx queries for Rust + PostgreSQL. Enforces compile-time checked queries, connection pool management, typed transactions, migration discipline, and repository pattern with scoped tenant isolation.
---

# SQLx PostgreSQL — Diretrizes Sênior (v0.8+)

## 1. Princípio Zero: Compile-Time Safety

SQLx verifica queries SQL **em tempo de compilação** contra o banco real. Isso elimina runtime SQL errors. NUNCA desabilite isso.

- **Skills complementares**: SEMPRE leia `axum-web`, `rust-lang` e `axum-multi-tenant` junto.
- **DATABASE_URL obrigatório**: `.env` deve ter `DATABASE_URL` para `cargo check` funcionar com `query!()`.
- **Offline mode**: Use `cargo sqlx prepare` para gerar `.sqlx/` cache para CI sem banco.

## 2. Cargo.toml — Features Obrigatórias

```toml
[dependencies]
sqlx = { version = "0.8", features = [
  "runtime-tokio",   # Tokio runtime
  "postgres",        # Driver PostgreSQL
  "uuid",            # Tipo UUID
  "chrono",          # Tipo DateTime
  "migrate",         # Migrations embutidas
  "json",            # Tipo JSONB
] }
```

## 3. Connection Pool

```rust
// CERTO: Pool com configuração explícita
use sqlx::postgres::PgPoolOptions;

let pool = PgPoolOptions::new()
    .max_connections(20)        // Ajustar por core de CPU
    .min_connections(5)
    .acquire_timeout(Duration::from_secs(5))
    .idle_timeout(Duration::from_secs(600))
    .max_lifetime(Duration::from_secs(1800))
    .connect(&database_url)
    .await?;

// ERRADO: Pool sem limites
let pool = PgPool::connect(&database_url).await?;
```

## 4. Queries — Compile-Time Checked

```rust
// CERTO: query_as! com tipo de retorno tipado
#[derive(sqlx::FromRow)]
pub struct Contact {
    pub id: Uuid,
    pub tenant_id: Uuid,
    pub name: String,
    pub email: Option<String>,
    pub created_at: DateTime<Utc>,
}

let contacts = sqlx::query_as!(
    Contact,
    r#"
    SELECT id, tenant_id, name, email, created_at
    FROM contacts
    WHERE tenant_id = $1 AND deleted_at IS NULL
    ORDER BY created_at DESC
    LIMIT $2 OFFSET $3
    "#,
    tenant_id,
    limit,
    offset
)
.fetch_all(&pool)
.await?;

// ERRADO: query() sem tipo (retorna Row genérico)
let rows = sqlx::query("SELECT * FROM contacts")
    .fetch_all(&pool)
    .await?;
```

### query_scalar! para valores únicos

```rust
let count = sqlx::query_scalar!(
    "SELECT COUNT(*) FROM contacts WHERE tenant_id = $1",
    tenant_id
)
.fetch_one(&pool)
.await?
.unwrap_or(0);
```

## 5. Transactions

```rust
// CERTO: Transaction com SET LOCAL para RLS
let mut tx = pool.begin().await?;

// Setar tenant context ANTES de qualquer query
sqlx::query("SET LOCAL app.current_tenant_id = $1")
    .bind(tenant_id)
    .execute(&mut *tx)
    .await?;

// Queries dentro da transação
sqlx::query!(
    "INSERT INTO contacts (tenant_id, name, email) VALUES ($1, $2, $3)",
    tenant_id, name, email
)
.execute(&mut *tx)
.await?;

tx.commit().await?;

// ERRADO: Esquecer SET LOCAL em multi-tenant
let mut tx = pool.begin().await?;
sqlx::query!("INSERT INTO contacts ...").execute(&mut *tx).await?;
tx.commit().await?; // RLS pode rejeitar!
```

## 6. Migrations

```bash
# Criar migration
cargo sqlx migrate add create_contacts_table

# Rodar migrations
cargo sqlx migrate run --database-url $DATABASE_URL

# Preparar cache offline para CI
cargo sqlx prepare --database-url $DATABASE_URL
```

### Estrutura

```
migrations/
├── 001_create_platform_schema.sql
├── 002_create_admins.sql
├── ...
└── 015_seed_data.sql
```

### Dogma: Migrations são imutáveis

- NUNCA edite uma migration já aplicada.
- Para corrigir, crie uma NOVA migration com ALTER TABLE.
- Migrations devem ser idempotentes quando possível.

## 7. Repository Pattern

```rust
pub struct ContactRepository;

impl ContactRepository {
    pub async fn find_all(
        pool: &PgPool,
        tenant_id: Uuid,
        page: i64,
        per_page: i64,
    ) -> Result<Vec<Contact>, sqlx::Error> {
        sqlx::query_as!(
            Contact,
            r#"
            SELECT id, tenant_id, name, email, phone, created_at
            FROM contacts
            WHERE tenant_id = $1 AND deleted_at IS NULL
            ORDER BY created_at DESC
            LIMIT $2 OFFSET $3
            "#,
            tenant_id,
            per_page,
            (page - 1) * per_page
        )
        .fetch_all(pool)
        .await
    }

    pub async fn find_by_id(
        pool: &PgPool,
        tenant_id: Uuid,
        id: Uuid,
    ) -> Result<Option<Contact>, sqlx::Error> {
        sqlx::query_as!(
            Contact,
            "SELECT * FROM contacts WHERE tenant_id = $1 AND id = $2 AND deleted_at IS NULL",
            tenant_id, id
        )
        .fetch_optional(pool)
        .await
    }

    pub async fn create(
        pool: &PgPool,
        tenant_id: Uuid,
        dto: CreateContactDto,
    ) -> Result<Contact, sqlx::Error> {
        sqlx::query_as!(
            Contact,
            r#"
            INSERT INTO contacts (tenant_id, name, email, phone)
            VALUES ($1, $2, $3, $4)
            RETURNING *
            "#,
            tenant_id, dto.name, dto.email, dto.phone
        )
        .fetch_one(pool)
        .await
    }
}
```

## 8. JSONB com sqlx::types::Json

```rust
use sqlx::types::Json;

#[derive(sqlx::FromRow)]
pub struct Automation {
    pub id: Uuid,
    pub conditions: Json<Vec<Condition>>,   // JSONB tipado
    pub action_config: Json<ActionConfig>,
}

#[derive(Serialize, Deserialize)]
pub struct Condition {
    pub field: String,
    pub op: String,
    pub value: serde_json::Value,
}
```

## 9. Soft Delete Pattern

```rust
// CERTO: Soft delete com deleted_at
pub async fn soft_delete(
    pool: &PgPool,
    tenant_id: Uuid,
    id: Uuid,
) -> Result<(), sqlx::Error> {
    sqlx::query!(
        "UPDATE contacts SET deleted_at = now() WHERE tenant_id = $1 AND id = $2",
        tenant_id, id
    )
    .execute(pool)
    .await?;
    Ok(())
}

// Toda query de leitura DEVE filtrar: WHERE deleted_at IS NULL
```

## 10. Full-Text Search

```rust
// Busca com tsvector
let contacts = sqlx::query_as!(
    Contact,
    r#"
    SELECT * FROM contacts
    WHERE tenant_id = $1
      AND deleted_at IS NULL
      AND search_vector @@ plainto_tsquery('portuguese', $2)
    ORDER BY ts_rank(search_vector, plainto_tsquery('portuguese', $2)) DESC
    LIMIT $3
    "#,
    tenant_id, query, limit
)
.fetch_all(pool)
.await?;
```

## Constraints — O que NUNCA Fazer

- ❌ NUNCA use `query()` genérico — sempre `query_as!()` ou `query_scalar!()`
- ❌ NUNCA faça `SELECT *` sem RETURNING — especifique colunas
- ❌ NUNCA esqueça WHERE tenant_id em queries multi-tenant
- ❌ NUNCA edite migrations já aplicadas
- ❌ NUNCA use `.unwrap()` em results de query — sempre `?` ou pattern match
- ❌ NUNCA crie Pool sem max_connections
