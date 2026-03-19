---
name: LGPD & Data Privacy Compliance
description: Architect, validate, and enforce data privacy compliance patterns for LGPD (Brazil) and GDPR (EU). Covers consent management, data subject rights (access, correction, deletion, portability), anonymization and pseudonymization techniques, data retention policies, audit trails, breach notification procedures, Privacy by Design, Data Protection Impact Assessment (DPIA), and DPO responsibilities. Rust backend + React frontend patterns.
---

# LGPD & Data Privacy Compliance — Diretrizes Senior+

## 0. Princípio Fundamental: Privacy by Design

Privacidade não é feature opcional — é **requisito arquitetural**:
- Coletar APENAS dados necessários (minimização).
- Armazenar APENAS pelo tempo necessário (retenção).
- Proteger SEMPRE com criptografia e controle de acesso.
-  registrar TODA operação sobre dados pessoais (audit trail).

> ⚠️ **Crime**: Sistema em produção que coleta dados pessoais sem base legal documentada, sem mecanismo de consentimento, e sem capacidade de atender direitos do titular. Multa ANPD: até 2% do faturamento (máx R$ 50 milhões por infração).

---

## 1. Bases Legais — Quando Posso Tratar Dados?

```
┌─────────────────────────────────────────────────────────────────┐
│ Base Legal           │ Quando Usar                              │
├──────────────────────┼──────────────────────────────────────────┤
│ Consentimento        │ Marketing, cookies, comunicações         │
│ Contrato             │ Dados necessários para prestar o serviço │
│ Obrigação Legal      │ Emissão de NF, eSocial, fiscal           │
│ Interesse Legítimo   │ Prevenção a fraudes, segurança           │
│ Proteção ao Crédito  │ Score, análise de crédito                │
│ Exercício de Direitos│ Processos judiciais/administrativos      │
└──────────────────────┴──────────────────────────────────────────┘

REGRA: TODA coleta de dado pessoal DEVE ter base legal documentada.
Se não tem base legal → NÃO coletar.
```

---

## 2. Consentimento — Implementação

### 2.1 Schema de Consentimento

```sql
-- Registro granular de consentimento por finalidade
CREATE TABLE consent_records (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id),
    user_id         UUID NOT NULL REFERENCES users(id),
    purpose         TEXT NOT NULL,        -- 'marketing_email', 'analytics', 'third_party_share'
    legal_basis     TEXT NOT NULL,        -- 'consent', 'contract', 'legal_obligation'
    granted         BOOLEAN NOT NULL,
    ip_address      INET,
    user_agent      TEXT,
    consent_text    TEXT NOT NULL,        -- texto exato apresentado ao usuário
    version         INT DEFAULT 1,       -- versão do texto de consentimento
    granted_at      TIMESTAMPTZ,
    revoked_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_consent_user ON consent_records(user_id, purpose);

-- Nunca deletar registros de consentimento — são prova legal
-- Revogar = INSERT novo registro com granted=false
```

### 2.2 API de Consentimento

```rust
// CERTO: consentimento granular por finalidade
async fn grant_consent(
    State(state): State<AppState>,
    session: Session,
    Json(dto): Json<ConsentDto>,
) -> Result<impl IntoResponse, AppError> {
    // Validar que purpose é válido
    let valid_purposes = ["marketing_email", "analytics", "third_party_share"];
    if !valid_purposes.contains(&dto.purpose.as_str()) {
        return Err(AppError::Validation("Invalid consent purpose".into()));
    }

    // Registrar consentimento com contexto completo
    sqlx::query!(
        r#"INSERT INTO consent_records
           (tenant_id, user_id, purpose, legal_basis, granted, ip_address, user_agent, consent_text, version, granted_at)
           VALUES ($1, $2, $3, 'consent', true, $4, $5, $6, $7, NOW())"#,
        session.tenant_id,
        session.user_id,
        dto.purpose,
        dto.ip_address,
        dto.user_agent,
        dto.consent_text, // texto EXATO apresentado — prova legal
        dto.version,
    )
    .execute(&state.db)
    .await?;

    audit_log(&state, "consent.granted", &session, &dto.purpose).await;

    Ok(StatusCode::OK)
}

// ERRADO: checkbox genérico "aceito tudo" — precisa ser granular
// ERRADO: consentimento pré-marcado — DEVE ser opt-in ativo
// ERRADO: sem registrar IP/user_agent/texto — sem prova de consentimento
```

---

## 3. Direitos do Titular (DSAR)

### 3.1 Direitos Obrigatórios

```
┌─────────────────────────────────────────────────────────────────┐
│ Direito            │ Prazo    │ Implementação                   │
├────────────────────┼──────────┼─────────────────────────────────┤
│ Acesso             │ 15 dias  │ Export JSON/CSV de todos os dados│
│ Correção           │ 15 dias  │ Endpoint de atualização          │
│ Anonimização       │ 15 dias  │ Substituir dados por hash/null   │
│ Portabilidade      │ 15 dias  │ Export em formato padrão (JSON)  │
│ Eliminação         │ 15 dias  │ Soft delete + anonimização       │
│ Info sobre compartilhamento │ 15 dias │ Lista de terceiros      │
│ Revogação de consentimento  │ Imediato │ Toggle por finalidade   │
└────────────────────┴──────────┴─────────────────────────────────┘
```

### 3.2 Data Subject Access Request (DSAR)

```rust
// CERTO: exportação completa de dados pessoais do titular
async fn export_user_data(
    State(state): State<AppState>,
    session: Session,
) -> Result<impl IntoResponse, AppError> {
    let user_id = session.user_id;

    // Coletar TODOS os dados pessoais do titular
    let personal_data = UserDataExport {
        profile: get_user_profile(&state.db, user_id).await?,
        contacts: get_user_contacts(&state.db, user_id).await?,
        activities: get_user_activities(&state.db, user_id).await?,
        consent_records: get_consent_history(&state.db, user_id).await?,
        login_history: get_login_history(&state.db, user_id).await?,
    };

    // Registrar no audit log
    audit_log(&state, "dsar.export", &session, "full_data_export").await;

    Ok(Json(json!({ "data": personal_data })))
}
```

---

## 4. Anonimização e Pseudonymização

```rust
// CERTO: anonimização irreversível (dado deixa de ser pessoal)
async fn anonymize_user(db: &PgPool, user_id: Uuid) -> Result<(), AppError> {
    let anon_hash = format!("ANON_{}", Uuid::new_v4());

    sqlx::query!(
        r#"UPDATE users SET
           name = $2,
           email = $3,
           phone = NULL,
           cpf = NULL,
           address = NULL,
           avatar_url = NULL,
           anonymized_at = NOW()
           WHERE id = $1"#,
        user_id,
        anon_hash,
        format!("{}@anon.invalid", anon_hash),
    )
    .execute(db)
    .await?;

    // Anonimizar dados relacionados
    sqlx::query!(
        "UPDATE contacts SET notes = NULL, custom_fields = '{}' WHERE created_by = $1",
        user_id
    )
    .execute(db)
    .await?;

    Ok(())
}

// Pseudonymização: substituição reversível (dado ainda é pessoal)
// → Usar AES-256-GCM para criptografar campos, chave em env var
// → Dado pode ser "despseudonymizado" com a chave

// ERRADO: DELETE em vez de anonimizar — perde integridade referencial
// ERRADO: anonimização que permite re-identificação — não é anônimo
```

---

## 5. Data Retention — Políticas

```sql
-- Tabela de políticas de retenção por entidade
CREATE TABLE data_retention_policies (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type     TEXT NOT NULL UNIQUE,  -- 'users', 'contacts', 'audit_logs'
    retention_days  INT NOT NULL,          -- dias para manter
    action          TEXT NOT NULL,         -- 'anonymize', 'delete', 'archive'
    legal_basis     TEXT,                  -- base legal para retenção
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Exemplos de política:
-- users:       365 dias após exclusão → anonimizar
-- audit_logs:  1825 dias (5 anos) → arquivar (obrigação legal)
-- sessions:    30 dias → deletar
-- consent:     NUNCA deletar (prova legal)
-- invoices:    1825 dias (5 anos) → arquivar (fiscal)
```

```rust
// CERTO: job de retenção — roda diariamente
async fn enforce_retention_policies(state: &AppState) -> Result<(), AppError> {
    let policies = sqlx::query_as!(RetentionPolicy,
        "SELECT * FROM data_retention_policies"
    )
    .fetch_all(&state.db)
    .await?;

    for policy in policies {
        let cutoff = Utc::now() - chrono::Duration::days(policy.retention_days as i64);

        match policy.action.as_str() {
            "anonymize" => {
                let count = anonymize_expired(&state.db, &policy.entity_type, cutoff).await?;
                tracing::info!(entity = %policy.entity_type, count, "Data anonymized (retention)");
            }
            "delete" => {
                let count = delete_expired(&state.db, &policy.entity_type, cutoff).await?;
                tracing::info!(entity = %policy.entity_type, count, "Data deleted (retention)");
            }
            "archive" => {
                let count = archive_expired(&state.db, &policy.entity_type, cutoff).await?;
                tracing::info!(entity = %policy.entity_type, count, "Data archived (retention)");
            }
            _ => {}
        }
    }

    Ok(())
}
```

---

## 6. Breach Notification — Incidentes

```
LGPD Resolução 15/2024:
- Prazo: 3 DIAS ÚTEIS para comunicar ANPD após tomar conhecimento.
- Comunicar titulares afetados em prazo razoável.
- Documentar: natureza dos dados, titulares afetados, medidas tomadas.

CHECKLIST DE INCIDENTE:
1. [ ] Detectar e confirmar o incidente
2. [ ] Classificar severidade (dados sensíveis? volume?)
3. [ ] Conter o incidente (revogar acessos, isolar sistemas)
4. [ ] Notificar ANPD em 3 dias úteis
5. [ ] Notificar titulares afetados
6. [ ] Documentar em relatório de incidente
7. [ ] Implementar medidas corretivas
8. [ ] Post-mortem e prevenção futura
```

---

## 7. Checklist — LGPD Compliance

- [ ] **Base legal documentada** — toda coleta tem justificativa registrada.
- [ ] **Consentimento granular** — opt-in ativo, por finalidade, revogável.
- [ ] **Registro de consentimento** — IP, user_agent, texto exato, timestamp.
- [ ] **DSAR** — export, correção, anonimização, portabilidade em 15 dias.
- [ ] **Anonimização** — irreversível, dado deixa de ser pessoal.
- [ ] **Pseudonymização** — AES-256-GCM, chave em env var, reversível.
- [ ] **Retenção** — políticas por entidade, job diário de enforcement.
- [ ] **Campos sensíveis criptografados** — CPF, telefone, endereço at rest.
- [ ] **Audit trail** — toda operação sobre dados pessoais logada.
- [ ] **Breach notification** — plano de incidente, 3 dias úteis para ANPD.
- [ ] **Minimização** — coletar APENAS o necessário, sem campos "por via das dúvidas".
- [ ] **DPO designado** — informações de contato público.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

