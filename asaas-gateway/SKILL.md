---
name: Asaas Payment Gateway API
description: Integrate, validate, and generate Asaas REST API calls for billing, subscriptions, customers, PIX, boleto, credit card, notifications, and webhook handling. Covers dual billing model (platform→tenant and tenant→customer) patterns.
---

# Asaas API — Diretrizes Sênior

## 1. Princípio Zero: Asaas é Billing, Não Database

Asaas gerencia cobranças e pagamentos. Dados de negócio vivem no PostgreSQL. Sincronize via webhooks.

- **Base URL Produção**: `https://api.asaas.com/v3`
- **Base URL Sandbox**: `https://sandbox.asaas.com/api/v3`
- **Auth**: Header `access_token: $ASAAS_API_KEY`
- **Rate Limit**: 100 requests/minuto por conta

## 2. Modelo Dual do ICBox CRM

| Contexto | Quem Cobra | Quem Paga | Chave Asaas |
|----------|------------|-----------|-------------|
| **Plataforma** | ICBox | Tenant | `ASAAS_PLATFORM_KEY` (env var) |
| **Módulo Tenant** | Tenant | Clientes do tenant | `asaas_configs.api_key_enc` (banco, AES-256-GCM) |

### Regra: NUNCA misture chaves
- Cobranças da plataforma usam APENAS a chave global
- Cobranças do tenant usam APENAS a chave dele (descriptografada em runtime)

## 3. Endpoints Principais

### Customers
```
POST   /v3/customers            — Criar cliente
GET    /v3/customers?email=...  — Buscar por email
GET    /v3/customers/:id        — Detalhe
PUT    /v3/customers/:id        — Atualizar
DELETE /v3/customers/:id        — Remover
```

### Cobranças (Payments)
```
POST   /v3/payments              — Criar cobrança
GET    /v3/payments/:id          — Detalhe
GET    /v3/payments?customer=... — Listar por cliente
PUT    /v3/payments/:id          — Atualizar
DELETE /v3/payments/:id          — Remover/Cancelar

GET    /v3/payments/:id/billingInfo  — Dados do boleto (linha digitável)
GET    /v3/payments/:id/pixQrCode   — QR Code PIX
```

### Subscriptions (Assinaturas)
```
POST   /v3/subscriptions             — Criar assinatura
GET    /v3/subscriptions/:id         — Detalhe
PUT    /v3/subscriptions/:id         — Atualizar
DELETE /v3/subscriptions/:id         — Cancelar

GET    /v3/subscriptions/:id/payments — Cobranças da assinatura
```

## 4. Criar Cobrança — Exemplo

```rust
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CreatePaymentDto {
    pub customer: String,        // Asaas customer ID
    pub billing_type: String,    // BOLETO, PIX, CREDIT_CARD, UNDEFINED
    pub value: f64,
    pub due_date: String,        // YYYY-MM-DD
    pub description: Option<String>,
    pub external_reference: Option<String>, // ID do tenant_subscription
}

// billing_type = "UNDEFINED" → gera boleto + PIX + cartão (cliente escolhe)
```

### billingType Options

| Valor | Descrição |
|-------|-----------|
| `BOLETO` | Apenas boleto |
| `PIX` | Apenas PIX |
| `CREDIT_CARD` | Apenas cartão |
| `UNDEFINED` | Todos os métodos (recomendado) |

## 5. Webhooks — Eventos

```
POST /api/v1/webhooks/asaas  — Endpoint que recebe eventos
```

### Eventos Principais

| Evento | Ação |
|--------|------|
| `PAYMENT_CREATED` | Log no banco |
| `PAYMENT_RECEIVED` | ✅ Ativar/renovar assinatura |
| `PAYMENT_CONFIRMED` | ✅ Confirmar pagamento (PIX) |
| `PAYMENT_OVERDUE` | ⚠️ Notificar tenant (vencido) |
| `PAYMENT_DELETED` | Log |
| `PAYMENT_REFUNDED` | ⚠️ Reverter ativação |
| `PAYMENT_UPDATED` | Atualizar status |

### Validação de Webhook

```rust
// CERTO: Validar token do webhook
fn validate_asaas_webhook(
    headers: &HeaderMap,
    expected_token: &str,
) -> bool {
    headers
        .get("asaas-access-token")
        .map(|v| v.to_str().unwrap_or("") == expected_token)
        .unwrap_or(false)
}
```

## 6. Fluxo de Billing da Plataforma

```
1. Admin cria tenant → status: active, trial_ends_at = now + trial_days
2. Cron diário verifica trial_ends_at:
   - Se expirou → cria customer Asaas + cobrança → status: pending_payment
3. Webhook PAYMENT_RECEIVED → ativa assinatura → status: active
4. Mensal: cria nova cobrança via subscription
5. Se não pago em 5 dias (grace_period) → status: suspended
6. Admin pode reativar manualmente
```

## 7. Rate Limiting & Error Handling

```rust
// Asaas retorna 429 quando excede rate limit
// Implementar retry com exponential backoff

pub async fn asaas_request<T: DeserializeOwned>(
    client: &reqwest::Client,
    method: reqwest::Method,
    path: &str,
    api_key: &str,
    body: Option<&impl Serialize>,
) -> Result<T, AsaasError> {
    let url = format!("{}{}", ASAAS_BASE_URL, path);
    let mut retries = 0;

    loop {
        let mut req = client.request(method.clone(), &url)
            .header("access_token", api_key)
            .header("Content-Type", "application/json");

        if let Some(b) = body {
            req = req.json(b);
        }

        let response = req.send().await?;

        match response.status().as_u16() {
            200..=299 => return Ok(response.json::<T>().await?),
            429 if retries < 3 => {
                retries += 1;
                tokio::time::sleep(Duration::from_millis(1000 * retries)).await;
                continue;
            }
            status => {
                let error_body = response.text().await?;
                return Err(AsaasError::ApiError { status, body: error_body });
            }
        }
    }
}
```

## Constraints

- ❌ NUNCA exponha a API key do Asaas no frontend
- ❌ NUNCA confie na chave de sandbox em produção
- ❌ NUNCA processe pagamento sem validar webhook token
- ❌ NUNCA use billingType hardcoded — permita configuração
- ❌ NUNCA ignore rate limiting — implemente retry com backoff
