---
name: API Security Hardening
description: Validate, enforce, and generate API security configurations covering HTTP security headers (CSP, HSTS, CORS, X-Frame-Options), rate limiting (governor, token bucket), input sanitization (whitelist validation, parameterized queries), SQL injection prevention, CSRF protection, WAF integration, and TLS enforcement. Rust/Axum + Node.js patterns.
---

# API Security Hardening — Diretrizes Senior+

## 0. Princípio Fundamental: Defense in Depth

Segurança de API é **camadas sobrepostas**, não um único portão:
- Header → Transport → Auth → Input → Query → Output → Logging.
- Se uma camada falhar, a próxima segura. NUNCA depender de uma única defesa.

> ⚠️ **Crime Arquitetural**: API em produção sem HTTPS, sem headers de segurança, sem rate limiting. Um único endpoint exposto é convite para ataque.

---

## 1. HTTP Security Headers — Obrigatórios

### 1.1 Configuração Padrão

```rust
// CERTO: middleware de security headers no Axum
use axum::middleware;
use axum::http::{HeaderName, HeaderValue};

async fn security_headers(
    request: axum::extract::Request,
    next: middleware::Next,
) -> axum::response::Response {
    let mut response = next.run(request).await;
    let headers = response.headers_mut();

    // HSTS — forçar HTTPS por 1 ano + subdomínios
    headers.insert(
        HeaderName::from_static("strict-transport-security"),
        HeaderValue::from_static("max-age=31536000; includeSubDomains; preload"),
    );

    // CSP — controlar origens de recursos
    headers.insert(
        HeaderName::from_static("content-security-policy"),
        HeaderValue::from_static("default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' https://fonts.gstatic.com; frame-ancestors 'none'"),
    );

    // Prevenir clickjacking
    headers.insert(
        HeaderName::from_static("x-frame-options"),
        HeaderValue::from_static("DENY"),
    );

    // Prevenir MIME sniffing
    headers.insert(
        HeaderName::from_static("x-content-type-options"),
        HeaderValue::from_static("nosniff"),
    );

    // Controlar referrer
    headers.insert(
        HeaderName::from_static("referrer-policy"),
        HeaderValue::from_static("strict-origin-when-cross-origin"),
    );

    // Desabilitar APIs perigosas do browser
    headers.insert(
        HeaderName::from_static("permissions-policy"),
        HeaderValue::from_static("camera=(), microphone=(), geolocation=(), payment=()"),
    );

    // Remover header que expõe tecnologia
    headers.remove("x-powered-by");
    headers.remove("server");

    response
}

// ERRADO: API sem nenhum security header
// ERRADO: CSP com 'unsafe-eval' — abre porta para XSS
// ERRADO: X-Frame-Options: SAMEORIGIN quando deveria ser DENY em APIs
```

### 1.2 CORS — Configuração Restritiva

```rust
// CERTO: CORS restritivo — apenas origens explícitas
use tower_http::cors::{CorsLayer, AllowOrigin};

let cors = CorsLayer::new()
    .allow_origin(AllowOrigin::list([
        "https://app.example.com".parse().unwrap(),
        "https://admin.example.com".parse().unwrap(),
    ]))
    .allow_methods([Method::GET, Method::POST, Method::PUT, Method::DELETE])
    .allow_headers([
        header::CONTENT_TYPE,
        header::AUTHORIZATION,
        HeaderName::from_static("x-tenant-id"),
    ])
    .allow_credentials(true)
    .max_age(Duration::from_secs(3600));

// ERRADO: allow_origin(Any) — NUNCA em produção
// ERRADO: allow_origin("*") com allow_credentials(true) — browser rejeita
// ERRADO: CORS sem max_age — preflight request a cada chamada
```

---

## 2. Rate Limiting

### 2.1 Camadas de Rate Limiting

```
┌────────────────────────────────────────────────┐
│ Camada 1: Global (por IP)                      │
│   → 100 req/min por IP — protege contra DDoS   │
├────────────────────────────────────────────────┤
│ Camada 2: Por Tenant (API key/token)            │
│   → 1000 req/min por tenant — fair usage        │
├────────────────────────────────────────────────┤
│ Camada 3: Por Endpoint (sensíveis)              │
│   → /login: 5 req/min — anti brute-force       │
│   → /forgot-password: 3 req/min                │
│   → /api/v1/bulk: 10 req/min                   │
└────────────────────────────────────────────────┘
```

### 2.2 Resposta 429

```rust
// CERTO: resposta 429 com Retry-After header
use axum::http::StatusCode;
use axum::response::IntoResponse;

fn rate_limited_response(retry_after_secs: u64) -> impl IntoResponse {
    (
        StatusCode::TOO_MANY_REQUESTS,
        [("Retry-After", retry_after_secs.to_string())],
        axum::Json(serde_json::json!({
            "error": {
                "code": "RATE_LIMITED",
                "message": "Too many requests. Please retry later.",
                "retry_after": retry_after_secs
            }
        })),
    )
}

// ERRADO: retornar 500 quando é rate limit (client não sabe o que fazer)
// ERRADO: rate limit sem Retry-After header (client faz polling agressivo)
```

---

## 3. Input Validation & Sanitization

### 3.1 Validação por Whitelist

```rust
// CERTO: validação no extractor level — rejeitar antes de processar
use axum::extract::Json;
use serde::Deserialize;
use validator::Validate;

#[derive(Deserialize, Validate)]
pub struct CreateContactDto {
    #[validate(length(min = 1, max = 200))]
    pub name: String,

    #[validate(email)]
    pub email: String,

    #[validate(phone)]
    pub phone: Option<String>,

    #[validate(length(max = 1000))]
    pub notes: Option<String>,

    // NUNCA aceitar HTML/script em campos de texto
    // Sanitizar no handler antes de persistir
}

async fn create_contact(
    Json(dto): Json<CreateContactDto>,
) -> Result<impl IntoResponse, AppError> {
    // Validar struct
    dto.validate().map_err(|e| AppError::Validation(e.to_string()))?;

    // Sanitizar campos de texto (strip HTML tags)
    let name = sanitize_text(&dto.name);
    let notes = dto.notes.as_deref().map(sanitize_text);

    // ... persistir
    Ok(StatusCode::CREATED)
}

/// Remover HTML tags e caracteres perigosos
fn sanitize_text(input: &str) -> String {
    input
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('&', "&amp;")
        .replace('"', "&quot;")
        .replace('\'', "&#x27;")
}

// ERRADO: aceitar qualquer string sem validação
// ERRADO: blacklist (tentar bloquear strings perigosas) — sempre falha
// ERRADO: validar apenas no frontend — bypass trivial
```

### 3.2 SQL Injection Prevention

```rust
// CERTO: SEMPRE queries parametrizadas (SQLx faz isso nativamente)
let user = sqlx::query_as!(
    User,
    "SELECT * FROM users WHERE email = $1 AND tenant_id = $2",
    email,     // parâmetro seguro — NUNCA interpolado
    tenant_id, // parâmetro seguro
)
.fetch_optional(&pool)
.await?;

// ERRADO: concatenação de string NUNCA
// let query = format!("SELECT * FROM users WHERE email = '{}'", email);
// ↑ SQL INJECTION GARANTIDA — PROIBIDO
```

---

## 4. TLS / HTTPS

```
REGRAS INVIOLÁVEIS:
- ✅ TLS 1.2+ em toda comunicação (TLS 1.3 preferido)
- ✅ HSTS header com max-age >= 1 ano
- ✅ Redirect HTTP → HTTPS (301)
- ✅ Certificado válido (Let's Encrypt ou equivalente)
- ❌ NUNCA permitir HTTP em produção
- ❌ NUNCA aceitar TLS 1.0 ou 1.1
- ❌ NUNCA desabilitar verificação de certificado em client HTTP
```

---

## 5. Error Handling Seguro

```rust
// CERTO: erros genéricos para o client, detalhados no log
async fn handle_error(err: AppError) -> impl IntoResponse {
    match &err {
        AppError::NotFound => {
            (StatusCode::NOT_FOUND, json_error("NOT_FOUND", "Resource not found"))
        }
        AppError::Unauthorized => {
            // NUNCA dizer "password incorreta" — dizer "credenciais inválidas"
            (StatusCode::UNAUTHORIZED, json_error("UNAUTHORIZED", "Invalid credentials"))
        }
        AppError::Internal(e) => {
            // Logar detalhes internamente
            tracing::error!(error = %e, "Internal server error");
            // Responder genérico — NUNCA expor stack trace
            (StatusCode::INTERNAL_SERVER_ERROR, json_error("INTERNAL_ERROR", "An unexpected error occurred"))
        }
        _ => {
            (StatusCode::BAD_REQUEST, json_error("BAD_REQUEST", "Invalid request"))
        }
    }
}

// ERRADO: retornar stack trace no response body
// ERRADO: "User not found" vs "Password wrong" — dá dica ao atacante
// ERRADO: expor nome de tabela/coluna em erro de banco
```

---

## 6. Checklist — API Security

- [ ] **HTTPS obrigatório** — TLS 1.2+ em produção, HTTP redireciona para HTTPS.
- [ ] **Security headers** — HSTS, CSP, X-Frame-Options, X-Content-Type-Options, Referrer-Policy.
- [ ] **CORS restritivo** — origens explícitas, NUNCA `*` em produção.
- [ ] **Rate limiting** — por IP, por tenant, por endpoint sensível (login, reset).
- [ ] **429 com Retry-After** — informar client quando pode retomar.
- [ ] **Input validation** — whitelist, validação server-side obrigatória, sanitização de HTML.
- [ ] **Queries parametrizadas** — NUNCA string concatenation em SQL.
- [ ] **Error handling seguro** — mensagens genéricas para client, detalhes no log.
- [ ] **Headers removidos** — X-Powered-By, Server header removidos.
- [ ] **Permissions-Policy** — desabilitar APIs desnecessárias (camera, mic, geo).
- [ ] **Request size limit** — body size máximo configurado (ex: 10MB).
- [ ] **Timeout em endpoints** — prevenir slow loris e request hanging.
