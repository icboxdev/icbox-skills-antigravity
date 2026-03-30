---
name: Axum Multi-Tenant Architecture & RLS
description: Consolidate the tactical complement for Axum SaaS Data Isolation. Interception of routes, JWT Middleware to Row-Level Security injection in PostgreSQL using SQLx.
---

# Axum Multi-Tenant Architecture & RLS

A arquitetura B2B SaaS demanda níveis supremos de isolamento. O Antigravity proibe que Clientes (Tenants) visualizem dados uns dos outros pela inépcia humana de esquecer um `WHERE tenant_id = ?` em uma Query extensa. Para resolver isto definitivamente, o Estado Compartilhado (AppState) converte o Middleware HTTP (Axum) para transações SQLx restritas pelo Kernel do PostgreSQL (RLS - Row Level Security).

## Arquitetura & Dogmas OBRIGATÓRIOS

- **PostgreSQL RLS**: O banco de dados PostgreSQL deve habilitar `ALTER TABLE x ENABLE ROW LEVEL SECURITY;`.
- **Politícas (Policies)**: Crie uma Policy global. `CREATE POLICY tenant_isolation ON x AS RESTRICTIVE USING (tenant_id = current_setting('request.jwt.claim.tenant_id')::uuid);`.
- **Obrigação do Axum JWT Middleware**: O Middleware extrai o JWT (Cookie HttpOnly), decoda o Claim `tenant_id` e introduz nos Extensions (`req.extensions_mut().insert(TenantContext(id))`).
- **SQLx Transaction Context**: Todas as consultas que tocam repositórios isolados devem instanciar e assinar uma transação LOCAL SET. O AppState não provê um Pool direto; Ele obriga a assinatura.

## Few-Shot: Autenticação Restrita (Injeção de RLS)

### 🟢 CORRETO
A camada do Repository que fala pela entidade de Domínio não expõe a inserção crua do RLS. Ela OBRIGA você a passar uma Transação pré-RLS instanciada pela Service, não um `&PgPool`.

```rust
use sqlx::{Transaction, Postgres};
use uuid::Uuid;

// Padrão Unit Of Work (Opcional) ou Wrapper Transacional Simplificado
// 1. Transaction Builder Centralizado
pub async fn begin_tenant_transaction<'a>(
    pool: &sqlx::PgPool,
    tenant_id: Uuid,
) -> Result<Transaction<'a, Postgres>, sqlx::Error> {
    let mut tx = pool.begin().await?;
    
    // Assegura que todas as próximas operações nesta TX sejam restritas no DB
    // Usa config_local pra n vazar entre connections retornadas pro pool
    sqlx::query!(
        "SELECT set_config('request.jwt.claim.tenant_id', $1::text, true)",
        tenant_id.to_string()
    )
    .execute(&mut *tx)
    .await?;
    
    Ok(tx)
}

// 2. O Handler Fino
pub async fn list_sensors(
    Extension(tenant): Extension<TenantContext>,
    State(state): State<AppState>
) -> Result<Json<Vec<Sensor>>, AppError> {
    let sensors = state.sensor_service().get_all_sensors(tenant.id).await?;
    Ok(Json(sensors))
}

// 3. A Service executa o Setup RLS e passa a TX limitante pro Respository 
impl SensorService {
    pub async fn get_all_sensors(&self, tenant_id: Uuid) -> Result<Vec<Sensor>, AppError> {
        let mut tx = begin_tenant_transaction(&self.db_pool, tenant_id).await?;
        
        let sensors = self.sensor_repository.fetch_all(&mut tx).await?;
        
        // Finaliza o block (neste caso so_read, rollback ou commit faria o msm)
        tx.commit().await?; 
        Ok(sensors)
    }
}

// 4. O Repositório é Cego: O Kernel Psql fará o filtro `where tenant = ?` oculto.
impl SensorRepository {
    // Note que EXIGIMOS uma TX (Postgres), n o Pool solto
    pub async fn fetch_all(&self, tx: &mut Transaction<'_, Postgres>) -> Result<Vec<Sensor>, sqlx::Error> {
        // NENHUM 'WHERE tenant_id =' PODE FUGIR, RLS APLICA MAGICA
        let rows = sqlx::query_as!(Sensor, "SELECT * FROM sensors ORDER BY created_at DESC")
            .fetch_all(&mut **tx).await?;
        Ok(rows)
    }
}
```

### 🔴 ERRADO
```rust
use axum::{Extension};

// Lógica no handler injetando vulnerabilidades na connection do Pool Solta.
pub async fn handle_sensor(Extension(tenant): Extension<TenantContext>, pool: State<PgPool>) {
    // 💀 ANTI-PATTERN MORAL. Definir variavel local de connection vazada de volta ao pool!
    // A próxima rota q emprestar essa conn rodará como se fosse ESSE tenant, 
    // revelando dados do cliente A para o cliente B e gerando PROCESSO DA LGPD.
    let mut conn = pool.acquire().await.unwrap();
    sqlx::query("SET LOCAL myapp.tenant_id = $1").bind(tenant.id).execute(&mut conn).await.unwrap();
    
    //... fetch params 
}
```

## Context Management & Restrições Zero-Trust

- **Sempre transacionar no PostgreSQL ao instanciar RLS (`SET LOCAL`)**. Modificar o ambiente em requisição limpa vai fazer as Connection Pools poluirem seu roteamento de requests por ID, e *vai* causar Data Leak.
- Em *Admin endpoints* (Backoffice Support Root), crie uma Policy PostgreSQL equivalente que dê By-Pass (Ignora RLS) caso o `role` interno passado via Set Local seja `SUPER_ADMIN`.
- Isso liberta o desenvolvedor Axum de precisar espalhar dezenas de filtros SQL (`WHERE tenant_id = '...'`).
