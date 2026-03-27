---
name: Authentication & Authorization Patterns
description: Architect, validate, and enforce authentication and authorization patterns covering OAuth2 flows (PKCE, client credentials), RBAC/ABAC hybrid models, session management (cookie-based, HttpOnly, SameSite), MFA implementation, Argon2id password hashing, JWT best practices (short-lived tokens, refresh rotation, reuse detection), and Zero Trust principles. Rust/Axum + React patterns.
---

# Authentication & Authorization Patterns — Diretrizes Senior+

## 0. Princípio Fundamental: Zero Trust, Always Verify

Autenticação responde "quem é você?". Autorização responde "o que você pode fazer?".
Ambas devem ser aplicadas em **todas as camadas**, NUNCA confiar apenas no frontend.

> ⚠️ **Crime**: API que confia no frontend para autorização. O frontend é decoração — toda regra de acesso é enforçada no backend. Sem exceção.

---

## 1. Autenticação — Cookie-Based (Padrão)

### 1.1 Fluxo de Login

```rust
// CERTO: login com cookie HttpOnly — NUNCA retornar JWT no body
use axum::http::header::SET_COOKIE;
use argon2::{Argon2, PasswordHash, PasswordVerifier};

async fn login(
    State(state): State<AppState>,
    Json(dto): Json<LoginDto>,
) -> Result<impl IntoResponse, AppError> {
    // 1. Buscar usuário (NUNCA revelar se email existe)
    let user = sqlx::query_as!(User,
        "SELECT * FROM users WHERE email = $1 AND deleted_at IS NULL",
        dto.email.to_lowercase().trim()
    )
    .fetch_optional(&state.db)
    .await?
    .ok_or(AppError::InvalidCredentials)?; // msg genérica

    // 2. Verificar senha com Argon2id
    let hash = PasswordHash::new(&user.password_hash)
        .map_err(|_| AppError::InvalidCredentials)?;
    Argon2::default()
        .verify_password(dto.password.as_bytes(), &hash)
        .map_err(|_| AppError::InvalidCredentials)?;

    // 3. Verificar lockout (5 tentativas → 15 min bloqueio)
    check_lockout(&state.db, user.id).await?;

    // 4. Criar session
    let session_id = create_session(&state.db, user.id, user.tenant_id).await?;

    // 5. Cookie HttpOnly + Secure + SameSite
    let cookie = format!(
        "session_id={}; HttpOnly; Secure; SameSite=Lax; Path=/; Max-Age=86400",
        session_id
    );

    // 6. Resetar contador de tentativas falhas
    reset_login_attempts(&state.db, user.id).await?;

    Ok((
        StatusCode::OK,
        [(SET_COOKIE, cookie)],
        Json(json!({ "data": { "user": UserResponse::from(user) } })),
    ))
}

// ERRADO: retornar JWT no response body — XSS rouba o token
// ERRADO: "Email não encontrado" vs "Senha errada" — enumeration attack
// ERRADO: bcrypt, SHA256, MD5 para senhas — SOMENTE Argon2id
// ERRADO: cookie sem HttpOnly — JavaScript acessa
// ERRADO: cookie sem Secure — enviado em HTTP
// ERRADO: SameSite=None sem Secure — browser rejeita
```

### 1.2 Password Hashing — Argon2id

```rust
// CERTO: Argon2id com parâmetros OWASP 2024
use argon2::{Argon2, Algorithm, Version, Params, PasswordHasher};
use argon2::password_hash::SaltString;
use rand_core::OsRng;

pub fn hash_password(password: &str) -> Result<String, AppError> {
    let salt = SaltString::generate(&mut OsRng);

    // Parâmetros OWASP: 19MiB memory, 2 iterations, 1 parallelism
    let params = Params::new(19456, 2, 1, None)
        .map_err(|e| AppError::Internal(e.to_string()))?;

    let argon2 = Argon2::new(Algorithm::Argon2id, Version::V0x13, params);

    let hash = argon2
        .hash_password(password.as_bytes(), &salt)
        .map_err(|e| AppError::Internal(e.to_string()))?;

    Ok(hash.to_string())
}

// ERRADO: bcrypt — vulnerável a GPU attacks
// ERRADO: SHA256/SHA512 — NUNCA para senhas (é hash, não KDF)
// ERRADO: MD5 — brokeníssimo
// ERRADO: salt fixo ou previsível — USAR OsRng
```

---

## 2. Autorização — RBAC + ABAC Híbrido

### 2.1 RBAC Base

```rust
// CERTO: middleware de autorização por role
#[derive(Debug, Clone, PartialEq, sqlx::Type)]
#[sqlx(type_name = "user_role", rename_all = "snake_case")]
pub enum UserRole {
    Owner,         // tudo no tenant
    Admin,         // gerenciar users, configs
    Manager,       // gerenciar equipe, relatórios
    Agent,         // operação diária
    Viewer,        // somente leitura
}

/// Middleware: verificar se user tem role mínima
pub fn require_role(minimum: UserRole) -> impl Fn(/* ... */) {
    move |session: &Session| {
        let role_level = match session.role {
            UserRole::Owner => 5,
            UserRole::Admin => 4,
            UserRole::Manager => 3,
            UserRole::Agent => 2,
            UserRole::Viewer => 1,
        };

        let required_level = match minimum {
            UserRole::Owner => 5,
            UserRole::Admin => 4,
            UserRole::Manager => 3,
            UserRole::Agent => 2,
            UserRole::Viewer => 1,
        };

        if role_level < required_level {
            return Err(AppError::Forbidden);
        }
        Ok(())
    }
}

// Uso nas rotas:
// .route("/users", post(create_user).route_layer(require_role(UserRole::Admin)))
// .route("/reports", get(list_reports).route_layer(require_role(UserRole::Manager)))
```

### 2.2 ABAC — Controle Granular

```rust
// CERTO: ABAC para decisões contextuais (além do RBAC base)
pub struct AccessContext {
    pub user_id: Uuid,
    pub user_role: UserRole,
    pub tenant_id: Uuid,
    pub resource_owner_id: Option<Uuid>,
    pub ip_address: String,
    pub time_of_day: chrono::NaiveTime,
}

pub fn can_access_resource(ctx: &AccessContext) -> bool {
    // Owners e Admins: acesso total
    if matches!(ctx.user_role, UserRole::Owner | UserRole::Admin) {
        return true;
    }

    // Agents: apenas recursos que eles possuem
    if ctx.user_role == UserRole::Agent {
        return ctx.resource_owner_id == Some(ctx.user_id);
    }

    // Viewers: apenas em horário comercial (ABAC contextual)
    if ctx.user_role == UserRole::Viewer {
        let hour = ctx.time_of_day.hour();
        return hour >= 8 && hour <= 18;
    }

    false
}
```

---

## 3. Session Management

```
REGRAS INVIOLÁVEIS:
- ✅ Session ID: mínimo 128 bits, gerado com CSPRNG
- ✅ Regenerar session ID após login (previne fixation)
- ✅ Timeout de inatividade: 30 min (configurável)
- ✅ Timeout absoluto: 24h (força re-login)
- ✅ Invalidar session no logout (DELETE da tabela)
- ✅ Armazenar sessions server-side (banco ou Redis)
- ❌ NUNCA armazenar session ID em localStorage
- ❌ NUNCA session ID previsível ou sequencial
- ❌ NUNCA reutilizar session ID após logout
```

---

## 4. JWT — Quando Necessário (M2M, Mobile)

```rust
// CERTO: JWT curto (15 min) + refresh token rotation
pub struct TokenPair {
    pub access_token: String,   // 15 min — stateless
    pub refresh_token: String,  // 7 dias — armazenado server-side
}

// Refresh token rotation: cada uso invalida o anterior
async fn refresh_token(
    state: &AppState,
    old_refresh: &str,
) -> Result<TokenPair, AppError> {
    // 1. Buscar refresh token no banco
    let token = sqlx::query_as!(RefreshToken,
        "SELECT * FROM refresh_tokens WHERE token = $1 AND revoked = false",
        old_refresh,
    )
    .fetch_optional(&state.db)
    .await?
    .ok_or(AppError::Unauthorized)?;

    // 2. Verificar expiração
    if token.expires_at < Utc::now() {
        return Err(AppError::Unauthorized);
    }

    // 3. REUSE DETECTION: se já foi usado, revogar TODOS do user
    if token.used {
        tracing::warn!(user_id = %token.user_id, "Refresh token reuse detected! Revoking all.");
        revoke_all_tokens(&state.db, token.user_id).await?;
        return Err(AppError::Unauthorized);
    }

    // 4. Marcar como usado
    mark_token_used(&state.db, token.id).await?;

    // 5. Gerar novo par
    let new_pair = generate_token_pair(&state, token.user_id, token.tenant_id)?;

    // 6. Persistir novo refresh token
    save_refresh_token(&state.db, &new_pair.refresh_token, token.user_id).await?;

    Ok(new_pair)
}

// ERRADO: refresh token sem rotation — roubou uma vez, acesso eterno
// ERRADO: JWT de 24h — window de ataque muito grande
// ERRADO: dados sensíveis no payload JWT — qualquer um decodifica
// ERRADO: algorithm "none" aceito — bypass total de assinatura
```

---

## 5. MFA — Multi-Factor Authentication

```
IMPLEMENTAÇÃO:
- ✅ TOTP (Time-based One-Time Password) via app (Google Authenticator, Authy)
- ✅ Backup codes (10 códigos de uso único, hashed no banco)
- ✅ Obrigatório para roles Admin+ (configurável)
- ❌ NUNCA SMS como único segundo fator — SIM swap vulnerável
- ❌ NUNCA armazenar TOTP secret em plaintext — criptografar (AES-256-GCM)

FLUXO:
1. Login com email/senha → valida credenciais
2. Se MFA ativo → retornar "mfa_required: true" (sem cookie ainda)
3. User envia código TOTP → validar
4. Se válido → criar session com cookie
5. Se inválido → incrementar contador de tentativas
```

---

## 6. Lockout — Anti Brute-Force

```rust
// CERTO: lockout progressivo
const MAX_ATTEMPTS: i32 = 5;
const LOCKOUT_DURATION: i64 = 15; // minutos

async fn check_lockout(db: &PgPool, user_id: Uuid) -> Result<(), AppError> {
    let attempts = sqlx::query_scalar!(
        "SELECT failed_attempts FROM users WHERE id = $1",
        user_id
    )
    .fetch_one(db)
    .await?;

    if attempts >= MAX_ATTEMPTS {
        let locked_until = sqlx::query_scalar!(
            "SELECT locked_until FROM users WHERE id = $1",
            user_id
        )
        .fetch_one(db)
        .await?;

        if let Some(until) = locked_until {
            if until > Utc::now() {
                return Err(AppError::AccountLocked {
                    minutes_remaining: (until - Utc::now()).num_minutes(),
                });
            }
            // Lockout expirou — resetar
            reset_login_attempts(db, user_id).await?;
        }
    }

    Ok(())
}

// ERRADO: sem lockout — brute force ilimitado
// ERRADO: lockout permanente — DoS por tentativas intencionais
// ERRADO: rate limit apenas por IP (atacante muda IP fácil)
```

---

## 7. Checklist — Auth & Authorization

- [ ] **Argon2id** — OWASP 2024 params, NUNCA bcrypt/SHA/MD5.
- [ ] **Cookie-based auth** — HttpOnly, Secure, SameSite=Lax.
- [ ] **Session server-side** — ID de 128+ bits, CSPRNG, regenerar no login.
- [ ] **RBAC base** — roles hierárquicos (Owner > Admin > Manager > Agent > Viewer).
- [ ] **ABAC contextual** — regras adicionais por atributos (owner, horário, IP).
- [ ] **JWT curto** — 15 min access, 7 dias refresh, rotation, reuse detection.
- [ ] **MFA** — TOTP obrigatório para Admin+, backup codes hashed.
- [ ] **Lockout** — 5 tentativas → 15 min bloqueio, progressivo.
- [ ] **Mensagens genéricas** — "Credenciais inválidas", NUNCA "email não encontrado".
- [ ] **Logout completo** — invalidar session, limpar cookie, revogar tokens.
- [ ] **Tenant isolation** — TODA query com WHERE tenant_id, sem exceção.
- [ ] **Audit log** — login, logout, failed attempt, role change, MFA toggle.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

