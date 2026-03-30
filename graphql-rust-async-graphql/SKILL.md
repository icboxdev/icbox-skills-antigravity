---
name: GraphQL Apollo Federation (Supergraph Rust)
description: Architect, generate, and validate GraphQL Federation utilizing async-graphql, Apollo Supergraph, and Subgraph schema design. Enforces static composition, DataLoaders for N+1 mitigation in Rust, and integration with Axum.
---

# GraphQL Apollo Federation (Rust / async-graphql)

A integração de GraphQL modernos recai sobre o ecosistema do **Apollo Federation**. Usamos o `async-graphql` em Rust como Subgraphs (microsserviços GraphQL isolados) focando em segurança, tipos estritos em tempo de compilação, e performance livre do N+1 através de `DataLoader`.

## Arquitetura & Dogmas OBRIGATÓRIOS

- **Use `async-graphql` com Axum**: Sem exceções, o ecossistema `async-graphql-axum` compila tipagens do GraphQL diretos da declaração de `structs` e `#Object` do Rust. Tudo é verificado.
- **N+1 é Falha Crítica**: NEVER exponha um campo `author(id)` que dispare selects unitários no banco. OBRIGATÓRIO envolver queries relacionais em um `DataLoader`.
- **Federation Subgraphs**: Ao modelar esquemas distribuídos, derive entidades com as macros de federação (ex: `#[graphql(entity)]`) indicando a Primary Key (`@key`) via atributos como `#[graphql(external)]`.
- **Injeção de Depedência In-Tree**: O estado local GraphQL (`Context<'ctx>`) deve receber a injeção do Pool (`PgPool`) ou extractores JWT antes de executar o router HTTP. Isso evita acessos inseguros no corpo da Query/Mutation.

## Few-Shot: DataLoader para Combater o N+1

### 🟢 CORRETO
```rust
use async_graphql::{dataloader::Loader, Context, Object, Result};
use std::collections::HashMap;
use sqlx::PgPool;

// 1. O Worker do Dataloader
pub struct UserLoader {
    pool: PgPool,
}

#[async_trait::async_trait]
impl Loader<uuid::Uuid> for UserLoader {
    type Value = User;
    type Error = std::sync::Arc<sqlx::Error>; // Erros precisam implementar Send+Clone+Sync na trait
    
    // Batch resolution
    async fn load(&self, keys: &[uuid::Uuid]) -> Result<std::collections::HashMap<uuid::Uuid, Self::Value>, Self::Error> {
        let rows = sqlx::query_as!(User, "SELECT * FROM users WHERE id = ANY($1)", keys)
            .fetch_all(&self.pool).await?;
        
        // Mapear O(1) pelo Key
        Ok(rows.into_iter().map(|u| (u.id, u)).collect())
    }
}

// 2. A Struct Relacional (Post)
pub struct Post {
    id: uuid::Uuid,
    author_id: uuid::Uuid,
    content: String,
}

#[Object]
impl Post {
    async fn id(&self) -> uuid::Uuid { self.id }
    async fn content(&self) -> &str { &self.content }

    // 3. Request Batching
    async fn author(&self, ctx: &Context<'_>) -> Result<Option<User>> {
        let loader = ctx.data_unchecked::<async_graphql::dataloader::DataLoader<UserLoader>>();
        let user = loader.load_one(self.author_id).await?;
        Ok(user)
    }
}
```

### 🔴 ERRADO
```rust
use async_graphql::{Context, Object, Result};
use sqlx::PgPool;

#[Object]
impl Post {
    // 💀 ANTI-PATTERN MORAL. Executará 100 queries se houverem 100 Posts devolvidos
    async fn author(&self, ctx: &Context<'_>) -> Result<User> {
         let pool = ctx.data_unchecked::<PgPool>();
         let user = sqlx::query_as!(User, "SELECT * FROM users WHERE id = $1", self.author_id)
            .fetch_one(pool).await?;
         Ok(user)
    }
}
```

## Few-Shot: Autenticação Restrita (Guards)

Nunca confie que o front-end está autorizado. Proteja Endpoints GraphQL Sensíveis com JWT injetados pelo `Context`.

### 🟢 CORRETO
```rust
use async_graphql::{Context, Object, Result, Guard};

pub struct QueryRoot;

// Restrição limpa por anotação
#[Object]
impl QueryRoot {
    #[graphql(guard = "RoleGuard::new(Role::Admin)")]
    async fn sensitive_admin_data(&self, ctx: &Context<'_>) -> Result<String> {
        Ok("Top Secret Enterprise Metrics".into())
    }
}
```

## Context Management & Restrições Zero-Trust

- Restrinja Mutações destrutivas. Não gere mutações "CRUD". O GraphQL deve focar no DOMAIN (ex: `approvePost`, `suspendUser`), e não `updateUser({status: "Suspended"})`. Isso previne brechas em tempo real.
- Sempre rode o schema linter via command line antes de deployar.
- Certifique-se nas integrações com o Axios/ApolloClient em React (`react-rust-auth`/`tanstack-query`) que Cookies C-Auth (HttpOnly) sejam enviados definindo `credentials: 'include'` nas requests para o subgrafo Rust.
