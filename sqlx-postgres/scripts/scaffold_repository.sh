#!/bin/bash
# Scaffold SQLx Rust Repository
if [ -z "$1" ]; then
    echo "Uso: $0 <EntityNamePascalCase> <table_name>"
    echo "Exemplo: $0 UserProfile user_profiles"
    exit 1
fi
ENTITY_PASCAL=$1
TABLE=$2
FILE="src/repositories/${TABLE}.rs"

echo "🦀 Scaffolding SQLx Repository: $ENTITY_PASCAL"
mkdir -p "src/repositories"

cat <<EOF > "$FILE"
use sqlx::{Postgres, Transaction};
use uuid::Uuid;

pub struct ${ENTITY_PASCAL}Repository;

impl ${ENTITY_PASCAL}Repository {
    /// Inserts a new record, strictly demanding a transaction object for atomic composite operations.
    pub async fn insert_tx(
        tx: &mut Transaction<'_, Postgres>,
        tenant_id: Uuid,
        /* TODO: pass DTO or model struct */
    ) -> Result<Uuid, sqlx::Error> {
        let rec = sqlx::query!(
            r#"
            INSERT INTO ${TABLE} (tenant_id)
            VALUES (\$1)
            RETURNING id
            "#,
            tenant_id
        )
        .fetch_one(&mut **tx)
        .await?;

        Ok(rec.id)
    }
}
EOF
echo "✅ SQLx: Repositório Gerado com injeção paramétrica em $FILE."
