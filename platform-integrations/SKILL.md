---
name: Platform Integrations Engineering
description: Architect, implement, and validate enterprise platform integrations covering webhook outbound/inbound (HMAC-SHA256, retry, DLQ, idempotency), API client design (reqwest, circuit breaker, rate limiting), OAuth2 M2M authentication, ERP/CRM adapter patterns, Brazilian government APIs (NFe, NFSe, eSocial, SPED, CNPJ, ViaCEP, IBGE, BrasilAPI), payment gateway integrations (PIX, Asaas, Stripe, MercadoPago, Open Banking), data synchronization patterns, and reconciliation workflows. Rust backend + React frontend.
---

# Platform Integrations Engineering — Diretrizes Senior+

## 0. Princípio Fundamental: Integração É Contrato, Não Gambiarra

Toda integração é um **contrato entre sistemas** — com responsabilidades claras de cada lado:
- Toda chamada externa DEVE ter: timeout, retry, circuit breaker, e log.
- Todo webhook recebido DEVE ter: verificação de assinatura, idempotência, e processamento assíncrono.
- Todo dado sincronizado DEVE ter: reconciliação periódica, conflict resolution, e audit trail.

> ⚠️ **Crime Arquitetural**: Chamar API externa sem timeout, sem retry, e swallowing errors silenciosamente. Integrações falham — o crime é não prever isso.

---

## 1. Arquitetura de Integrações

### 1.1 Fluxo Geral

```
[Seu Sistema]                    [Hub de Integrações]              [Sistemas Externos]
     │                                  │                                │
     ├─ Evento interno ──────────────► │ Event Bus (in-process)        │
     │   (order.created)               │   → Route to Adapters         │
     │                                  │       │                       │
     │                                  │       ├─ ERP Adapter ──────► │ TOTVS, SAP, Omie
     │                                  │       ├─ CRM Adapter ──────► │ HubSpot, Salesforce
     │                                  │       ├─ Fiscal Adapter ───► │ NFe/NFSe (Focus, NS)
     │                                  │       ├─ Payment Adapter ──► │ Asaas, Stripe, PIX
     │                                  │       └─ Webhook Dispatcher  │ → Clientes (outbound)
     │                                  │                               │
     │                                  │ Webhook Receiver ◄──────────── │ (inbound)
     │                                  │   → Verify HMAC               │
     │                                  │   → Dedup (idempotency)       │
     │                                  │   → Enqueue → Process async   │
     │                                  │                               │
     └── Reconciliation Job ──────────► │ Cron: compara dados ───────► │ Pull state
```

### 1.2 Princípios Arquiteturais

| Princípio | Regra |
|---|---|
| **Adapter Pattern** | Cada sistema externo tem 1 adapter isolado. Mudança de provedor = trocar adapter, sem mudar core. |
| **Fail-safe** | Falha de integração NUNCA bloqueia operação principal. Enfileirar e tentar depois. |
| **Idempotência** | Toda operação de sincronização DEVE ser idempotente. Reprocessar é seguro. |
| **Audit Trail** | Toda chamada externa é logada: request, response, status, duração. |
| **Timeout** | Toda chamada HTTP: connect_timeout=5s, request_timeout=30s. NUNCA sem timeout. |
| **Multi-tenant** | Cada tenant pode ter suas próprias credenciais e configurações de integração. |

---

## 2. API Client — Design Resiliente (Rust)

### 2.1 HTTP Client com Retry e Circuit Breaker

```rust
// CERTO: API client com retry, timeout, circuit breaker e logging
use reqwest::Client;
use std::time::Duration;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// Configuração padrão do HTTP client — reusar globalmente
pub fn build_http_client() -> Client {
    Client::builder()
        .connect_timeout(Duration::from_secs(5))
        .timeout(Duration::from_secs(30))
        .pool_max_idle_per_host(10)
        .user_agent("ICBox-Integration/1.0")
        .build()
        .expect("Failed to build HTTP client")
}

/// Fazer request com retry e exponential backoff
pub async fn request_with_retry<T: for<'de> Deserialize<'de>>(
    client: &Client,
    method: reqwest::Method,
    url: &str,
    body: Option<&impl Serialize>,
    headers: &[(String, String)],
    max_retries: u32,
) -> Result<T, IntegrationError> {
    let mut attempt = 0;
    let mut last_error = None;

    loop {
        attempt += 1;
        let request_id = Uuid::new_v4();

        let mut req = client.request(method.clone(), url);

        // Headers
        for (key, value) in headers {
            req = req.header(key.as_str(), value.as_str());
        }

        // Body
        if let Some(b) = body {
            req = req.json(b);
        }

        let start = std::time::Instant::now();

        match req.send().await {
            Ok(response) => {
                let status = response.status();
                let duration = start.elapsed();

                tracing::info!(
                    request_id = %request_id,
                    url = %url,
                    status = %status,
                    duration_ms = %duration.as_millis(),
                    attempt = attempt,
                    "External API call"
                );

                if status.is_success() {
                    return response.json::<T>().await.map_err(IntegrationError::Parse);
                }

                // Erro permanente (4xx exceto 429) — não retry
                if status.is_client_error() && status != reqwest::StatusCode::TOO_MANY_REQUESTS {
                    let body = response.text().await.unwrap_or_default();
                    return Err(IntegrationError::ClientError { status, body });
                }

                // 429 ou 5xx — retry
                if attempt > max_retries {
                    let body = response.text().await.unwrap_or_default();
                    return Err(IntegrationError::Exhausted { status, body, attempts: attempt });
                }

                last_error = Some(format!("HTTP {status}"));
            }
            Err(e) => {
                tracing::warn!(
                    request_id = %request_id,
                    url = %url,
                    error = %e,
                    attempt = attempt,
                    "External API call failed"
                );

                if attempt > max_retries {
                    return Err(IntegrationError::Network(e));
                }

                last_error = Some(e.to_string());
            }
        }

        // Exponential backoff com jitter
        let base_delay = Duration::from_millis(500 * 2u64.pow(attempt - 1));
        let jitter = Duration::from_millis(rand::random::<u64>() % 500);
        tokio::time::sleep(base_delay + jitter).await;
    }
}

#[derive(Debug, thiserror::Error)]
pub enum IntegrationError {
    #[error("Network error: {0}")]
    Network(#[from] reqwest::Error),

    #[error("Client error {status}: {body}")]
    ClientError { status: reqwest::StatusCode, body: String },

    #[error("Retries exhausted after {attempts} attempts, last status {status}: {body}")]
    Exhausted { status: reqwest::StatusCode, body: String, attempts: u32 },

    #[error("Parse error: {0}")]
    Parse(reqwest::Error),

    #[error("Auth error: {0}")]
    Auth(String),
}

// ERRADO: reqwest sem timeout — request trava forever
// ERRADO: retry em 400 Bad Request — nunca vai funcionar
// ERRADO: retry sem backoff — DDoS no provedor
```

### 2.2 OAuth2 Token Cache (M2M)

```rust
// CERTO: OAuth2 client credentials com cache thread-safe
use std::sync::Arc;
use tokio::sync::RwLock;
use chrono::{DateTime, Utc, Duration as ChronoDuration};

#[derive(Clone)]
struct CachedToken {
    access_token: String,
    expires_at: DateTime<Utc>,
}

pub struct OAuth2Client {
    http: Client,
    client_id: String,
    client_secret: String,
    token_url: String,
    cached: Arc<RwLock<Option<CachedToken>>>,
}

impl OAuth2Client {
    /// Obter token válido (do cache ou novo)
    pub async fn get_token(&self) -> Result<String, IntegrationError> {
        // Tentar cache primeiro (read lock — barato)
        {
            let cache = self.cached.read().await;
            if let Some(token) = cache.as_ref() {
                // Margem de 60s antes de expirar
                if token.expires_at > Utc::now() + ChronoDuration::seconds(60) {
                    return Ok(token.access_token.clone());
                }
            }
        }

        // Token expirado ou inexistente — obter novo (write lock)
        let mut cache = self.cached.write().await;

        // Double-check após write lock
        if let Some(token) = cache.as_ref() {
            if token.expires_at > Utc::now() + ChronoDuration::seconds(60) {
                return Ok(token.access_token.clone());
            }
        }

        // Fetch novo token
        let response = self.http
            .post(&self.token_url)
            .form(&[
                ("grant_type", "client_credentials"),
                ("client_id", &self.client_id),
                ("client_secret", &self.client_secret),
            ])
            .send()
            .await
            .map_err(IntegrationError::Network)?;

        if !response.status().is_success() {
            let body = response.text().await.unwrap_or_default();
            return Err(IntegrationError::Auth(format!("Token request failed: {body}")));
        }

        let token_resp: TokenResponse = response.json().await
            .map_err(IntegrationError::Parse)?;

        let expires_at = Utc::now() + ChronoDuration::seconds(token_resp.expires_in);

        *cache = Some(CachedToken {
            access_token: token_resp.access_token.clone(),
            expires_at,
        });

        tracing::info!("OAuth2 token refreshed, expires in {}s", token_resp.expires_in);
        Ok(token_resp.access_token)
    }
}

#[derive(Deserialize)]
struct TokenResponse {
    access_token: String,
    expires_in: i64,
    token_type: String,
}

// ERRADO: buscar token novo a cada request — 3x mais lento + rate limit
// ERRADO: cache sem expiração — token expira e requests falham
// ERRADO: não usar double-check no write lock — race condition
```

---

## 3. Webhook Inbound — Recebendo Webhooks

### 3.1 Receiver Seguro com HMAC

```rust
// CERTO: webhook receiver com HMAC-SHA256, idempotência, e processamento async
use axum::{extract::{State, Json}, http::{HeaderMap, StatusCode}};
use hmac::{Hmac, Mac};
use sha2::Sha256;
use subtle::ConstantTimeEq; // timing-safe comparison

type HmacSha256 = Hmac<Sha256>;

/// Webhook receiver endpoint — responder RÁPIDO (< 2s)
async fn receive_webhook(
    State(state): State<AppState>,
    headers: HeaderMap,
    body: axum::body::Bytes, // raw body para HMAC
) -> StatusCode {
    // 1. Extrair signature do header
    let signature = match headers.get("X-Signature-256") {
        Some(sig) => sig.to_str().unwrap_or_default().to_string(),
        None => {
            tracing::warn!("Webhook sem signature header");
            return StatusCode::UNAUTHORIZED;
        }
    };

    // 2. Verificar HMAC-SHA256 com constant-time comparison
    let secret = &state.webhook_secret;
    let mut mac = HmacSha256::new_from_slice(secret.as_bytes())
        .expect("HMAC key error");
    mac.update(&body);
    let expected = hex::encode(mac.finalize().into_bytes());

    let sig_clean = signature.strip_prefix("sha256=").unwrap_or(&signature);
    if !bool::from(expected.as_bytes().ct_eq(sig_clean.as_bytes())) {
        tracing::warn!("Webhook HMAC verification failed");
        return StatusCode::UNAUTHORIZED;
    }

    // 3. Parse payload
    let payload: serde_json::Value = match serde_json::from_slice(&body) {
        Ok(p) => p,
        Err(e) => {
            tracing::error!(error = %e, "Webhook parse error");
            return StatusCode::BAD_REQUEST;
        }
    };

    // 4. Verificar idempotência (dedup)
    let event_id = payload["id"].as_str().unwrap_or_default();
    if event_id.is_empty() {
        tracing::warn!("Webhook sem event ID");
        return StatusCode::BAD_REQUEST;
    }

    // Check Redis para dedup (TTL 24h)
    let dedup_key = format!("webhook:dedup:{}", event_id);
    let already_processed: bool = redis::cmd("SET")
        .arg(&dedup_key)
        .arg("1")
        .arg("NX")        // only set if not exists
        .arg("EX")
        .arg(86400)        // TTL 24h
        .query_async(&mut state.redis)
        .await
        .unwrap_or(false);

    if !already_processed {
        tracing::info!(event_id = %event_id, "Webhook already processed (dedup)");
        return StatusCode::OK; // ACK sem reprocessar
    }

    // 5. Enfileirar para processamento assíncrono — NUNCA processar inline
    let job = WebhookJob {
        event_id: event_id.to_string(),
        event_type: payload["event"].as_str().unwrap_or_default().to_string(),
        payload: payload.clone(),
        received_at: Utc::now(),
    };

    if let Err(e) = state.job_queue.enqueue(job).await {
        tracing::error!(error = %e, "Failed to enqueue webhook job");
        return StatusCode::INTERNAL_SERVER_ERROR;
    }

    tracing::info!(event_id = %event_id, "Webhook received and enqueued");

    // 6. Responder RÁPIDO — 200 OK
    StatusCode::OK
}

// ERRADO: processar webhook inline (API lenta → timeout → retry → loop)
// ERRADO: verificar HMAC com == (timing attack)
// ERRADO: sem dedup — reprocessa pagamento duplicado
// ERRADO: responder 200 antes de enfileirar (se enqueue falha, evento perdido)
```

### 3.2 Webhook Job Processor

```rust
// CERTO: processor com pattern matching por event type
async fn process_webhook_job(state: &AppState, job: WebhookJob) -> Result<(), IntegrationError> {
    match job.event_type.as_str() {
        // === Pagamentos ===
        "PAYMENT_CONFIRMED" | "PAYMENT_RECEIVED" => {
            let payment = serde_json::from_value::<PaymentWebhook>(job.payload)?;
            handle_payment_confirmed(state, &payment).await?;
        }
        "PAYMENT_OVERDUE" => {
            let payment = serde_json::from_value::<PaymentWebhook>(job.payload)?;
            handle_payment_overdue(state, &payment).await?;
        }
        "PAYMENT_REFUNDED" => {
            let payment = serde_json::from_value::<PaymentWebhook>(job.payload)?;
            handle_payment_refund(state, &payment).await?;
        }

        // === Notas Fiscais ===
        "NFE_AUTHORIZED" => {
            let nfe = serde_json::from_value::<NFeWebhook>(job.payload)?;
            handle_nfe_authorized(state, &nfe).await?;
        }
        "NFE_REJECTED" => {
            let nfe = serde_json::from_value::<NFeWebhook>(job.payload)?;
            handle_nfe_rejected(state, &nfe).await?;
        }

        // === CRM ===
        "DEAL_WON" | "DEAL_LOST" => {
            let deal = serde_json::from_value::<DealWebhook>(job.payload)?;
            handle_deal_status_change(state, &deal).await?;
        }

        _ => {
            tracing::warn!(event = %job.event_type, "Unknown webhook event type");
            // Não falhar — logar e seguir (novos eventos do provedor)
        }
    }

    // Log de processamento bem-sucedido
    log_webhook_processed(state, &job).await?;

    Ok(())
}
```

---

## 4. Webhook Outbound — Disparando Webhooks

### 4.1 Dispatcher com Retry e DLQ

```rust
// CERTO: webhook outbound com HMAC signing, retry, e DLQ
pub async fn dispatch_webhook(
    state: &AppState,
    subscription: &WebhookSubscription,
    event: &WebhookEvent,
) -> Result<(), IntegrationError> {
    let payload = serde_json::to_string(&event)?;

    // 1. Assinar com HMAC-SHA256
    let mut mac = HmacSha256::new_from_slice(subscription.secret.as_bytes())
        .expect("HMAC key error");
    mac.update(payload.as_bytes());
    let signature = format!("sha256={}", hex::encode(mac.finalize().into_bytes()));

    // 2. Tentar entregar com retry (max 5 tentativas)
    let max_attempts = 5;
    let mut attempt = 0;
    let mut last_status = None;

    loop {
        attempt += 1;

        let result = state.http_client
            .post(&subscription.url)
            .header("Content-Type", "application/json")
            .header("X-Webhook-Signature", &signature)
            .header("X-Webhook-Event", &event.event_type)
            .header("X-Webhook-ID", event.id.to_string())
            .header("X-Webhook-Timestamp", Utc::now().to_rfc3339())
            .body(payload.clone())
            .timeout(Duration::from_secs(10))
            .send()
            .await;

        match result {
            Ok(response) if response.status().is_success() => {
                // Entregue com sucesso
                log_delivery(state, &event.id, attempt, "delivered", None).await;
                return Ok(());
            }
            Ok(response) => {
                last_status = Some(response.status().as_u16());
                tracing::warn!(
                    url = %subscription.url,
                    status = %response.status(),
                    attempt = attempt,
                    "Webhook delivery failed"
                );
            }
            Err(e) => {
                tracing::warn!(
                    url = %subscription.url,
                    error = %e,
                    attempt = attempt,
                    "Webhook delivery error"
                );
            }
        }

        if attempt >= max_attempts {
            break;
        }

        // Backoff: 1s, 5s, 30s, 2m, 10m
        let delays = [1, 5, 30, 120, 600];
        let delay = delays.get((attempt - 1) as usize).copied().unwrap_or(600);
        tokio::time::sleep(Duration::from_secs(delay)).await;
    }

    // 3. DLQ — todas as tentativas falharam
    tracing::error!(
        url = %subscription.url,
        event_id = %event.id,
        "Webhook delivery exhausted — moving to DLQ"
    );

    log_delivery(state, &event.id, attempt, "dlq", last_status).await;

    // Persistir na dead letter queue para reprocessamento manual
    sqlx::query!(
        r#"INSERT INTO webhook_dlq (event_id, subscription_id, payload, last_status, attempts, created_at)
           VALUES ($1, $2, $3, $4, $5, NOW())"#,
        event.id,
        subscription.id,
        &payload,
        last_status.map(|s| s as i32),
        attempt as i32,
    )
    .execute(&state.db)
    .await?;

    Ok(())
}
```

---

## 5. APIs Governamentais Brasileiras

### 5.1 Catálogo de APIs

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ API                 │ Finalidade                    │ Base URL / Provedor   │
├─────────────────────┼───────────────────────────────┼───────────────────────┤
│ ViaCEP              │ Consulta de CEP → endereço    │ viacep.com.br/ws/     │
│ BrasilAPI           │ CNPJ, CEP, bancos, feriados   │ brasilapi.com.br/api  │
│ ReceitaWS           │ Dados CNPJ (3/min free)       │ receitaws.com.br      │
│ IBGE Localidades    │ Estados, municípios, códigos  │ servicodados.ibge.gov │
│ IBGE Agregados      │ Dados censitários / SIDRA     │ servicodados.ibge.gov │
│ Banco Central       │ Câmbio, SELIC, IPCA, CDI      │ api.bcb.gov.br        │
│ Focus NFe           │ Emissão NFe/NFCe/NFSe         │ focusnfe.com.br       │
│ NS Tecnologia       │ Emissão NFe/NFSe/MDFe         │ nstecnologia.com.br   │
│ TecnoSpeed          │ NFSe Nacional, eSocial, SPED  │ tecnospeed.com.br     │
│ PlugNotas           │ NFe/NFSe unificada            │ plugnotas.com.br      │
│ NFE.io              │ Emissão NFe simplificada      │ nfe.io                │
│ Asaas               │ Pagamentos (PIX, boleto, CC)  │ api.asaas.com/v3      │
│ Mercado Pago        │ Pagamentos + PIX              │ api.mercadopago.com   │
│ PagSeguro           │ Pagamentos + PIX              │ api.pagseguro.com     │
│ Stripe              │ Pagamentos internacionais     │ api.stripe.com        │
│ Open Banking BR     │ Dados bancários, PIX, contas  │ FAPI-BR compliant     │
└─────────────────────┴───────────────────────────────┴───────────────────────┘
```

### 5.2 Adapter Pattern — Exemplo Fiscal

```rust
// CERTO: adapter para emissão de notas fiscais — abstrair provedor
#[async_trait]
pub trait FiscalAdapter: Send + Sync {
    /// Emitir nota fiscal (NF-e ou NFS-e)
    async fn emit_invoice(&self, data: InvoiceData) -> Result<InvoiceResult, IntegrationError>;

    /// Cancelar nota fiscal
    async fn cancel_invoice(&self, invoice_id: &str, reason: &str) -> Result<(), IntegrationError>;

    /// Consultar status
    async fn get_invoice_status(&self, invoice_id: &str) -> Result<InvoiceStatus, IntegrationError>;
}

/// Adapter para Focus NFe
pub struct FocusNFeAdapter {
    http: Client,
    base_url: String,
    api_token: String,
}

#[async_trait]
impl FiscalAdapter for FocusNFeAdapter {
    async fn emit_invoice(&self, data: InvoiceData) -> Result<InvoiceResult, IntegrationError> {
        let focus_payload = FocusNFePayload::from(data); // DTO → formato Focus

        let result: FocusNFeResponse = request_with_retry(
            &self.http,
            reqwest::Method::POST,
            &format!("{}/v2/nfe", self.base_url),
            Some(&focus_payload),
            &[("Authorization".into(), format!("Bearer {}", self.api_token))],
            3,
        ).await?;

        Ok(InvoiceResult {
            external_id: result.ref_,
            access_key: result.chave_nfe,
            status: InvoiceStatus::Processing,
            pdf_url: result.url_danfe,
            xml_url: result.url_xml,
        })
    }

    // ... cancel_invoice, get_invoice_status
}

/// Adapter alternativo para NS Tecnologia
pub struct NsTecnologiaAdapter { /* ... */ }

#[async_trait]
impl FiscalAdapter for NsTecnologiaAdapter {
    // Mesma interface, implementação diferente
    // Trocar provedor = trocar adapter, zero mudança no core
}

// Registro no AppState
pub struct IntegrationAdapters {
    pub fiscal: Box<dyn FiscalAdapter>,
    pub payment: Box<dyn PaymentAdapter>,
    pub address: Box<dyn AddressAdapter>,
    pub cnpj: Box<dyn CnpjAdapter>,
}
```

### 5.3 Consultas Auxiliares — CEP, CNPJ, IBGE

```rust
// CERTO: consulta de CEP com fallback entre provedores
pub struct AddressService {
    http: Client,
}

impl AddressService {
    /// Consultar CEP — ViaCEP como primário, BrasilAPI como fallback
    pub async fn lookup_cep(&self, cep: &str) -> Result<Address, IntegrationError> {
        let cep_clean = cep.replace(['-', '.', ' '], "");

        if cep_clean.len() != 8 || !cep_clean.chars().all(|c| c.is_ascii_digit()) {
            return Err(IntegrationError::Validation("CEP inválido".into()));
        }

        // Tentar ViaCEP primeiro
        match self.lookup_viacep(&cep_clean).await {
            Ok(addr) => return Ok(addr),
            Err(e) => tracing::warn!(cep = %cep_clean, error = %e, "ViaCEP failed, trying BrasilAPI"),
        }

        // Fallback: BrasilAPI
        self.lookup_brasilapi(&cep_clean).await
    }

    async fn lookup_viacep(&self, cep: &str) -> Result<Address, IntegrationError> {
        let url = format!("https://viacep.com.br/ws/{cep}/json/");
        let resp: ViaCepResponse = request_with_retry(
            &self.http, reqwest::Method::GET, &url, None::<&()>, &[], 2,
        ).await?;

        if resp.erro.unwrap_or(false) {
            return Err(IntegrationError::NotFound("CEP não encontrado".into()));
        }

        Ok(Address {
            street: resp.logradouro,
            neighborhood: resp.bairro,
            city: resp.localidade,
            state: resp.uf,
            zip_code: cep.to_string(),
            ibge_code: resp.ibge,
        })
    }

    async fn lookup_brasilapi(&self, cep: &str) -> Result<Address, IntegrationError> {
        let url = format!("https://brasilapi.com.br/api/cep/v2/{cep}");
        let resp: BrasilApiCepResponse = request_with_retry(
            &self.http, reqwest::Method::GET, &url, None::<&()>, &[], 2,
        ).await?;

        Ok(Address {
            street: resp.street,
            neighborhood: resp.neighborhood,
            city: resp.city,
            state: resp.state,
            zip_code: cep.to_string(),
            ibge_code: Some(resp.city_ibge),
        })
    }
}

// CERTO: consulta de CNPJ com cache Redis (dados mudam raramente)
pub struct CnpjService {
    http: Client,
    redis: redis::aio::MultiplexedConnection,
}

impl CnpjService {
    pub async fn lookup_cnpj(&self, cnpj: &str) -> Result<CompanyData, IntegrationError> {
        let cnpj_clean = cnpj.replace(['.', '/', '-', ' '], "");

        // Cache Redis (TTL 7 dias — dados CNPJ mudam raramente)
        let cache_key = format!("cnpj:{cnpj_clean}");
        if let Ok(cached) = redis::cmd("GET").arg(&cache_key).query_async::<String>(&mut self.redis.clone()).await {
            if let Ok(data) = serde_json::from_str::<CompanyData>(&cached) {
                return Ok(data);
            }
        }

        // BrasilAPI (gratuito, sem autenticação)
        let url = format!("https://brasilapi.com.br/api/cnpj/v1/{cnpj_clean}");
        let resp: BrasilApiCnpjResponse = request_with_retry(
            &self.http, reqwest::Method::GET, &url, None::<&()>, &[], 2,
        ).await?;

        let data = CompanyData::from(resp);

        // Cachear
        let json = serde_json::to_string(&data).unwrap_or_default();
        let _: () = redis::cmd("SET")
            .arg(&cache_key).arg(&json).arg("EX").arg(604800) // 7 dias
            .query_async(&mut self.redis.clone())
            .await
            .unwrap_or_default();

        Ok(data)
    }
}
```

---

## 6. Integrações de Pagamento

### 6.1 Payment Adapter — Interface Unificada

```rust
// CERTO: trait unificada para gateways de pagamento
#[async_trait]
pub trait PaymentAdapter: Send + Sync {
    /// Criar cobrança (boleto, PIX, cartão)
    async fn create_charge(&self, data: ChargeData) -> Result<ChargeResult, IntegrationError>;

    /// Consultar status de cobrança
    async fn get_charge(&self, external_id: &str) -> Result<ChargeStatus, IntegrationError>;

    /// Estornar cobrança
    async fn refund(&self, external_id: &str, amount: Option<f64>) -> Result<(), IntegrationError>;

    /// Gerar QR Code PIX
    async fn create_pix(&self, data: PixData) -> Result<PixResult, IntegrationError>;

    /// Listar cobranças para reconciliação
    async fn list_charges(&self, filter: ChargeFilter) -> Result<Vec<ChargeResult>, IntegrationError>;
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ChargeData {
    pub customer_external_id: String,
    pub amount: f64,                     // em reais (100.50)
    pub billing_type: BillingType,       // PIX, BOLETO, CREDIT_CARD
    pub due_date: NaiveDate,
    pub description: String,
    pub external_reference: String,      // ID interno para reconciliação
    pub fine_value: Option<f64>,         // multa após vencimento
    pub interest_value: Option<f64>,     // juros diários
    pub installment_count: Option<u32>,  // parcelas (cartão)
}

#[derive(Debug, Serialize, Deserialize)]
pub enum BillingType {
    Pix,
    Boleto,
    CreditCard,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct PixResult {
    pub qr_code: String,          // payload do QR Code
    pub qr_code_image: String,    // base64 ou URL da imagem
    pub expiration: DateTime<Utc>,
    pub external_id: String,
}
```

### 6.2 Reconciliação de Pagamentos

```rust
// CERTO: job de reconciliação — roda diariamente comparando provedor vs banco local
pub async fn reconcile_payments(
    state: &AppState,
    tenant_id: Uuid,
    date: NaiveDate,
) -> Result<ReconciliationReport, IntegrationError> {
    let adapter = &state.integrations.payment;

    // 1. Buscar cobranças do provedor para o dia
    let external_charges = adapter.list_charges(ChargeFilter {
        date_from: date,
        date_to: date,
        statuses: vec!["CONFIRMED", "RECEIVED", "REFUNDED"],
    }).await?;

    // 2. Buscar cobranças locais para o dia
    let local_charges = sqlx::query_as!(
        LocalCharge,
        r#"SELECT id, external_id, amount, status, reconciled
           FROM charges
           WHERE tenant_id = $1 AND due_date = $2"#,
        tenant_id, date,
    )
    .fetch_all(&state.db)
    .await?;

    let mut report = ReconciliationReport::default();

    // 3. Comparar: provedor vs local
    for ext in &external_charges {
        match local_charges.iter().find(|l| l.external_id == ext.external_id) {
            Some(local) => {
                // Verificar se status está sincronizado
                if local.status != ext.status {
                    report.status_mismatches.push(StatusMismatch {
                        external_id: ext.external_id.clone(),
                        local_status: local.status.clone(),
                        external_status: ext.status.clone(),
                    });

                    // Auto-corrigir status local
                    update_charge_status(&state.db, local.id, &ext.status).await?;
                }

                // Verificar valor
                if (local.amount - ext.amount).abs() > 0.01 {
                    report.amount_mismatches.push(AmountMismatch {
                        external_id: ext.external_id.clone(),
                        local_amount: local.amount,
                        external_amount: ext.amount,
                    });
                }

                // Marcar como reconciliado
                mark_reconciled(&state.db, local.id).await?;
                report.matched += 1;
            }
            None => {
                // Existe no provedor mas não localmente — criar
                report.missing_local.push(ext.external_id.clone());
            }
        }
    }

    // 4. Cobranças locais sem correspondência no provedor
    for local in &local_charges {
        if !external_charges.iter().any(|e| e.external_id == local.external_id) {
            report.missing_external.push(local.external_id.clone());
        }
    }

    // 5. Persistir relatório
    save_reconciliation_report(&state.db, tenant_id, date, &report).await?;

    tracing::info!(
        tenant = %tenant_id,
        date = %date,
        matched = report.matched,
        mismatches = report.status_mismatches.len() + report.amount_mismatches.len(),
        "Payment reconciliation complete"
    );

    Ok(report)
}
```

---

## 7. Sincronização de Dados — Padrões

### 7.1 Sync Bidirecional com Conflict Resolution

```rust
// CERTO: sync bidirecional com timestamp-based conflict resolution
#[derive(Debug)]
pub enum SyncDirection {
    Push,      // local → externo
    Pull,      // externo → local
    Bidirectional, // ambos
}

#[derive(Debug)]
pub enum ConflictResolution {
    LastWriteWins,    // mais recente ganha
    LocalWins,        // local sempre tem prioridade
    ExternalWins,     // externo sempre tem prioridade
    Manual,           // marcar para revisão manual
}

pub async fn sync_contacts(
    state: &AppState,
    tenant_id: Uuid,
    direction: SyncDirection,
    conflict_strategy: ConflictResolution,
) -> Result<SyncReport, IntegrationError> {
    let crm_adapter = &state.integrations.crm;
    let mut report = SyncReport::default();

    match direction {
        SyncDirection::Pull | SyncDirection::Bidirectional => {
            // Buscar contatos do CRM externo
            let external = crm_adapter.list_contacts(
                &format!("updated_after:{}", last_sync_timestamp)
            ).await?;

            for ext_contact in external {
                match find_local_by_external_id(&state.db, tenant_id, &ext_contact.id).await? {
                    Some(local) => {
                        // Existe localmente — verificar conflito
                        if local.updated_at > ext_contact.updated_at {
                            match conflict_strategy {
                                ConflictResolution::ExternalWins => {
                                    update_local_contact(&state.db, local.id, &ext_contact).await?;
                                    report.updated += 1;
                                }
                                ConflictResolution::LocalWins => {
                                    report.skipped += 1;
                                }
                                ConflictResolution::LastWriteWins => {
                                    // Mais recente ganha
                                    if ext_contact.updated_at > local.updated_at {
                                        update_local_contact(&state.db, local.id, &ext_contact).await?;
                                        report.updated += 1;
                                    } else {
                                        report.skipped += 1;
                                    }
                                }
                                ConflictResolution::Manual => {
                                    create_sync_conflict(&state.db, tenant_id, &local, &ext_contact).await?;
                                    report.conflicts += 1;
                                }
                            }
                        } else {
                            // Sem conflito — atualizar local
                            update_local_contact(&state.db, local.id, &ext_contact).await?;
                            report.updated += 1;
                        }
                    }
                    None => {
                        // Novo — criar localmente
                        create_local_contact(&state.db, tenant_id, &ext_contact).await?;
                        report.created += 1;
                    }
                }
            }
        }
        _ => {}
    }

    // Push: local → externo (mesma lógica invertida)
    // ...

    Ok(report)
}
```

### 7.2 Mapeamento de Campos (Field Mapping)

```rust
// CERTO: field mapping configurável por tenant (cada ERP tem campos diferentes)
#[derive(Debug, Deserialize, Serialize)]
pub struct FieldMapping {
    pub source_field: String,      // campo no sistema externo
    pub target_field: String,      // campo no sistema local
    pub transform: Option<FieldTransform>,
}

#[derive(Debug, Deserialize, Serialize)]
pub enum FieldTransform {
    /// Converter para uppercase
    Uppercase,
    /// Converter para lowercase
    Lowercase,
    /// Aplicar máscara (ex: CPF)
    Mask(String),
    /// Mapear valores (ex: "Active" → "ativo")
    ValueMap(HashMap<String, String>),
    /// Data: converter formato
    DateFormat { from: String, to: String },
    /// Valor padrão se campo vazio
    DefaultValue(String),
    /// Concatenar múltiplos campos
    Concat { fields: Vec<String>, separator: String },
}

/// Aplicar mapeamento a um registro
pub fn apply_field_mapping(
    source: &serde_json::Value,
    mappings: &[FieldMapping],
) -> serde_json::Value {
    let mut target = serde_json::Map::new();

    for mapping in mappings {
        let value = source.get(&mapping.source_field).cloned().unwrap_or_default();

        let transformed = match &mapping.transform {
            Some(FieldTransform::Uppercase) => {
                serde_json::Value::String(value.as_str().unwrap_or_default().to_uppercase())
            }
            Some(FieldTransform::ValueMap(map)) => {
                let key = value.as_str().unwrap_or_default();
                serde_json::Value::String(
                    map.get(key).cloned().unwrap_or_else(|| key.to_string())
                )
            }
            Some(FieldTransform::DefaultValue(default)) => {
                if value.is_null() || value.as_str().map_or(false, |s| s.is_empty()) {
                    serde_json::Value::String(default.clone())
                } else {
                    value
                }
            }
            None => value,
            _ => value,
        };

        target.insert(mapping.target_field.clone(), transformed);
    }

    serde_json::Value::Object(target)
}
```

---

## 8. Schemas de Banco de Dados

```sql
-- Tabelas essenciais para gerenciamento de integrações

-- Configurações de integração por tenant
CREATE TABLE integration_configs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id),
    provider        TEXT NOT NULL,    -- 'asaas', 'focusnfe', 'hubspot'
    category        TEXT NOT NULL,    -- 'payment', 'fiscal', 'crm', 'erp'
    credentials     BYTEA NOT NULL,  -- AES-256-GCM encrypted
    settings        JSONB DEFAULT '{}',
    is_active       BOOLEAN DEFAULT true,
    last_synced_at  TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (tenant_id, provider)
);

-- Log de todas as chamadas externas (audit trail)
CREATE TABLE integration_logs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL,
    provider        TEXT NOT NULL,
    direction       TEXT NOT NULL,     -- 'outbound' | 'inbound'
    method          TEXT,              -- 'POST', 'GET'
    url             TEXT,
    status_code     INT,
    request_body    JSONB,             -- sem dados sensíveis
    response_body   JSONB,
    duration_ms     INT,
    error           TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_integration_logs_tenant_created
    ON integration_logs (tenant_id, created_at DESC);

-- Webhook subscriptions (outbound — clientes inscrevem)
CREATE TABLE webhook_subscriptions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL,
    url             TEXT NOT NULL,
    secret          TEXT NOT NULL,      -- HMAC secret
    events          TEXT[] NOT NULL,    -- ['payment.confirmed', 'deal.won']
    is_active       BOOLEAN DEFAULT true,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Delivery log (cada tentativa de entrega)
CREATE TABLE webhook_deliveries (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id UUID NOT NULL REFERENCES webhook_subscriptions(id),
    event_id        UUID NOT NULL,
    event_type      TEXT NOT NULL,
    status          TEXT NOT NULL,      -- 'delivered', 'failed', 'dlq'
    status_code     INT,
    attempts        INT DEFAULT 1,
    last_attempt_at TIMESTAMPTZ DEFAULT NOW(),
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Dead Letter Queue (webhooks que falharam em todas as tentativas)
CREATE TABLE webhook_dlq (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id        UUID NOT NULL,
    subscription_id UUID NOT NULL,
    payload         JSONB NOT NULL,
    last_status     INT,
    attempts        INT,
    reprocessed     BOOLEAN DEFAULT false,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Dedup de webhooks recebidos (complementa Redis)
CREATE TABLE webhook_received (
    event_id        TEXT PRIMARY KEY,
    provider        TEXT NOT NULL,
    event_type      TEXT NOT NULL,
    processed       BOOLEAN DEFAULT false,
    received_at     TIMESTAMPTZ DEFAULT NOW()
);

-- Field mappings configuráveis por tenant
CREATE TABLE field_mappings (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL,
    integration_id  UUID NOT NULL REFERENCES integration_configs(id),
    entity_type     TEXT NOT NULL,     -- 'contact', 'deal', 'product'
    mappings        JSONB NOT NULL,    -- array de FieldMapping
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Sync state tracking
CREATE TABLE sync_state (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL,
    integration_id  UUID NOT NULL REFERENCES integration_configs(id),
    entity_type     TEXT NOT NULL,
    last_sync_at    TIMESTAMPTZ,
    last_cursor     TEXT,              -- cursor/offset para paginação
    sync_status     TEXT DEFAULT 'idle', -- 'idle', 'running', 'error'
    error_message   TEXT,
    records_synced  INT DEFAULT 0,
    UNIQUE (tenant_id, integration_id, entity_type)
);

-- Reconciliation reports
CREATE TABLE reconciliation_reports (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL,
    category        TEXT NOT NULL,     -- 'payment', 'invoice'
    report_date     DATE NOT NULL,
    matched         INT DEFAULT 0,
    mismatches      INT DEFAULT 0,
    missing_local   INT DEFAULT 0,
    missing_external INT DEFAULT 0,
    details         JSONB,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 9. Estrutura de Projeto

```
backend/ (Rust — Axum)
├── src/
│   ├── integrations/
│   │   ├── mod.rs                  # IntegrationAdapters registry
│   │   ├── http_client.rs          # build_http_client, request_with_retry
│   │   ├── oauth2.rs               # OAuth2Client com token cache
│   │   ├── error.rs                # IntegrationError enum
│   │   │
│   │   ├── webhooks/
│   │   │   ├── mod.rs
│   │   │   ├── receiver.rs         # Inbound: HMAC verify + dedup + enqueue
│   │   │   ├── dispatcher.rs       # Outbound: sign + send + retry + DLQ
│   │   │   ├── processor.rs        # Job processor (pattern match by event)
│   │   │   └── routes.rs           # POST /webhooks/:provider
│   │   │
│   │   ├── fiscal/
│   │   │   ├── mod.rs              # FiscalAdapter trait
│   │   │   ├── focus_nfe.rs        # Focus NFe adapter
│   │   │   ├── ns_tecnologia.rs    # NS Tecnologia adapter
│   │   │   └── dto.rs              # InvoiceData, InvoiceResult
│   │   │
│   │   ├── payments/
│   │   │   ├── mod.rs              # PaymentAdapter trait
│   │   │   ├── asaas.rs            # Asaas adapter (PIX, boleto, CC)
│   │   │   ├── stripe.rs           # Stripe adapter
│   │   │   ├── mercado_pago.rs     # MercadoPago adapter
│   │   │   ├── reconciliation.rs   # Reconciliation job
│   │   │   └── dto.rs              # ChargeData, PixResult
│   │   │
│   │   ├── address/
│   │   │   ├── mod.rs              # AddressService (CEP lookup)
│   │   │   ├── viacep.rs           # ViaCEP adapter
│   │   │   └── brasilapi.rs        # BrasilAPI adapter
│   │   │
│   │   ├── cnpj/
│   │   │   ├── mod.rs              # CnpjService
│   │   │   └── brasilapi.rs        # BrasilAPI CNPJ adapter
│   │   │
│   │   ├── crm/
│   │   │   ├── mod.rs              # CrmAdapter trait
│   │   │   ├── hubspot.rs          # HubSpot adapter
│   │   │   └── salesforce.rs       # Salesforce adapter
│   │   │
│   │   ├── erp/
│   │   │   ├── mod.rs              # ErpAdapter trait
│   │   │   ├── omie.rs             # Omie ERP adapter
│   │   │   └── totvs.rs            # TOTVS Protheus adapter
│   │   │
│   │   └── sync/
│   │       ├── mod.rs              # Sync engine
│   │       ├── field_mapping.rs    # FieldMapping + transforms
│   │       ├── conflict.rs         # ConflictResolution
│   │       └── reconciliation.rs   # Generic reconciliation
│   │
│   └── migrations/
│       ├── 020_integration_configs.sql
│       ├── 021_webhook_tables.sql
│       ├── 022_sync_state.sql
│       └── 023_reconciliation.sql
```

---

## 10. Checklist Senior+ — Integrações

- [ ] **Adapter Pattern** — cada provedor encapsulado, trocar sem afetar core.
- [ ] **Timeout obrigatório** — connect=5s, request=30s em toda chamada HTTP.
- [ ] **Retry com backoff** — exponential + jitter, max 5 tentativas.
- [ ] **Circuit breaker** — após N falhas consecutivas, parar de chamar por X minutos.
- [ ] **HMAC-SHA256** — verificação em todo webhook inbound, constant-time comparison.
- [ ] **Idempotência** — dedup por event_id (Redis SET NX + TTL 24h).
- [ ] **Processamento async** — webhook recebido → enqueue → ACK rápido (< 2s).
- [ ] **DLQ** — webhooks que falharam em todas as tentativas persistidos para replay.
- [ ] **OAuth2 token cache** — RwLock + double-check, margem de 60s antes de expirar.
- [ ] **Credentials encrypted** — AES-256-GCM em repouso, chave via env var.
- [ ] **Integration logs** — toda chamada externa logada (sem dados sensíveis).
- [ ] **CEP fallback** — ViaCEP → BrasilAPI, nunca depender de um único provedor.
- [ ] **CNPJ cache** — Redis TTL 7 dias, dados mudam raramente.
- [ ] **Reconciliação** — job diário comparando provedor vs banco local.
- [ ] **Field mapping** — configurável por tenant, com transforms (uppercase, value map).
- [ ] **Sync state** — cursor/last_sync_at por entidade, retomável após falha.
- [ ] **Multi-tenant** — cada tenant tem suas próprias credenciais e configurações.
- [ ] **Rate limiting** — respeitar limites do provedor (ex: ReceitaWS 3/min free).
- [ ] **Webhook outbound** — HMAC signing, retry com backoff progressivo (1s→10m).
- [ ] **Zero secrets no código** — tudo via variáveis de ambiente ou secret manager.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

