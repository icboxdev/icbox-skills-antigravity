#!/bin/bash
# Scaffold Axum Domain Module
# Usage: ./scaffold_domain.sh <domain_name_snake_case> <DomainNamePascalCase>

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Erro: Faltam argumentos."
    echo "Uso: $0 <domain_name_snake_case> <DomainNamePascalCase>"
    echo "Exemplo: $0 user_profile UserProfile"
    exit 1
fi

DOMAIN_LOWER=$1
DOMAIN_PASCAL=$2
TARGET_DIR="src/domains/$DOMAIN_LOWER"

echo "🛠️ Scaffolding Axum domain: $DOMAIN_LOWER em $TARGET_DIR..."

mkdir -p "$TARGET_DIR"

# DTO
cat <<EOF > "$TARGET_DIR/dto.rs"
use serde::{Deserialize, Serialize};
use validator::Validate;
use uuid::Uuid;

#[derive(Debug, Deserialize, Serialize, Validate)]
pub struct Create${DOMAIN_PASCAL}Dto {
    // TODO: Adicione os campos de request aqui
}

#[derive(Debug, Serialize)]
pub struct ${DOMAIN_PASCAL}ResponseDto {
    pub id: Uuid,
    pub tenant_id: Uuid,
    // TODO: Adicione os campos de resposta aqui
}
EOF

# REPOSITORY
cat <<EOF > "$TARGET_DIR/repository.rs"
use sqlx::PgPool;
use uuid::Uuid;

pub struct ${DOMAIN_PASCAL}Repository;

impl ${DOMAIN_PASCAL}Repository {
    pub async fn create(pool: &PgPool, tenant_id: Uuid) -> Result<(), sqlx::Error> {
        // TODO: Isolar a query por tenant_id obrigatoriamente
        // sqlx::query!("INSERT INTO ${DOMAIN_LOWER}s (tenant_id) VALUES ($1)", tenant_id)
        //     .execute(pool).await?;
        Ok(())
    }
}
EOF

# SERVICE
cat <<EOF > "$TARGET_DIR/service.rs"
use sqlx::PgPool;
use uuid::Uuid;
use super::repository::${DOMAIN_PASCAL}Repository;
use super::dto::{Create${DOMAIN_PASCAL}Dto, ${DOMAIN_PASCAL}ResponseDto};

pub struct ${DOMAIN_PASCAL}Service;

impl ${DOMAIN_PASCAL}Service {
    pub async fn create(pool: &PgPool, tenant_id: Uuid, dto: Create${DOMAIN_PASCAL}Dto) -> Result<${DOMAIN_PASCAL}ResponseDto, String> {
        ${DOMAIN_PASCAL}Repository::create(pool, tenant_id).await.map_err(|e| e.to_string())?;
        
        Ok(${DOMAIN_PASCAL}ResponseDto {
            id: Uuid::new_v4(),
            tenant_id,
        })
    }
}
EOF

# CONTROLLER
cat <<EOF > "$TARGET_DIR/controller.rs"
use axum::{extract::State, Json, routing::{get, post}, Router};
use super::dto::{Create${DOMAIN_PASCAL}Dto, ${DOMAIN_PASCAL}ResponseDto};
use super::service::${DOMAIN_PASCAL}Service;
// Certifique-se de importar o AppState e o Extrator de Tenant do seu projeto
// use crate::{state::AppState, extractors::TenantContext};

pub fn router() -> Router</* AppState */> {
    Router::new()
        .route("/", post(create_${DOMAIN_LOWER}))
}

async fn create_${DOMAIN_LOWER}(
    // State(state): State<AppState>,
    // tenant: TenantContext,
    Json(payload): Json<Create${DOMAIN_PASCAL}Dto>,
) -> Result<Json<${DOMAIN_PASCAL}ResponseDto>, String> {
    // let result = ${DOMAIN_PASCAL}Service::create(&state.pool, tenant.id, payload).await?;
    // Ok(Json(result))
    Err("Endpoint not implemented yet".into())
}
EOF

# MOD EJECTIONS
cat <<EOF > "$TARGET_DIR/mod.rs"
pub mod controller;
pub mod service;
pub mod repository;
pub mod dto;
EOF

echo "✅ Domínio '$DOMAIN_PASCAL' criado com sucesso seguindo Controller -> Service -> Repository dogmas."
