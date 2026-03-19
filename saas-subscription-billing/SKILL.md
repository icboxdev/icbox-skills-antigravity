---
name: SaaS Subscription & Billing Architecture
description: Architect, validate, and generate SaaS subscription models, usage-based billing, payment gateway integrations (Stripe, Asaas), idempotent webhooks, proration, and dunning management.
---

# SaaS Subscription & Billing Architecture Mastery

This skill enforces architectural standards for building robust B2B and B2C SaaS billing systems. It covers the complete lifecycle: pricing models, payments, upgrades/downgrades (proration), churn prevention (dunning), and asynchronous state synchronization.

## ZERO-TRUST & SECURITY RULES
*   **NEVER Trust Client Pricing:** Prices, discounts, and quotas MUST ALWAYS be calculated and enforced on the server. The client only sends INTENT (e.g., `plan_id`), NEVER amounts.
*   **Idempotency is Mandatory:** Webhooks from payment gateways (Stripe, Asaas) guarantee AT-LEAST-ONCE delivery. You MUST process them idempotently to prevent duplicate charges or double upgrades.
*   **Source of Truth:** The Payment Gateway is the Source of Truth for payment status and subscription cycles. The local database is a synchronized read-replica of this state.

## 1. Architectural Dogmas

### Idempotent Webhooks (The Golden Rule)
Payment events can arrive multiple times or out of order.
1. Extract the unique `event_id` from the webhook payload.
2. Attempt to insert the `event_id` into an `processed_events` table (or Redis) with a UNIQUE constraint.
3. If it violates the unique constraint (already processed), immediately return `200 OK` without side effects.
4. Process the business logic asynchronously if possible, but ENSURE the `200 OK` is sent to the gateway within milliseconds to prevent retries.

### Usage-Based Pricing (Metered Billing)
*   **Decouple Usage from Billing:** Usage tracking should be highly available and low-latency (e.g., Redis, Kafka). Do not write to the billing database on every API call.
*   **Batch Reporting:** Aggregate usage over windows (e.g., hourly) and report batched usage to the billing provider (Stripe/Asaas) to avoid rate limits.
*   **Proration Handling:** For usage-based models, mid-cycle changes often require manual proration logic (creating invoice items for consumed usage before the plan switch) because standard gateway proration usually only applies to fixed-seat licenses.

### Dunning & Involuntary Churn
*   **Automated Retries:** Configure smart retries in the gateway (e.g., 3 days, 5 days, 7 days after failure).
*   **Grace Periods:** Do not immediately lock the user out on the first failed payment. Use a `status = 'past_due'` state with a 3-7 day grace period where the app shows persistent warnings but retains core functionality.
*   **Webhooks for Dunning:** Listen to `invoice.payment_failed` to trigger internal emails and in-app banners. Listen to `invoice.paid` to clear the `past_due` state securely.

## 2. Few-Shot Examples

### Webhook Idempotency (Rust / Axum Pattern)

**❌ INCORRECT (Race Conditions & Duplicates)**
```rust
// Vulnerable to duplicate webhooks leading to multiple DB updates
async fn handle_stripe_webhook(State(db): State<PgPool>, payload: Bytes) -> impl IntoResponse {
    let event: StripeEvent = serde_json::from_slice(&payload).unwrap();
    if event.type_ == "invoice.paid" {
        // ERROR: No idempotency check. If Stripe sends this twice, we process twice.
        grant_subscription_access(&db, event.customer_id).await;
    }
    StatusCode::OK
}
```

**✅ CORRECT (Strict Idempotency via DB Constraint)**
```rust
async fn handle_stripe_webhook(State(db): State<PgPool>, payload: Bytes) -> impl IntoResponse {
    let event: StripeEvent = match serde_json::from_slice(&payload) {
        Ok(e) => e,
        Err(_) => return StatusCode::BAD_REQUEST,
    };

    // 1. Check idempotency: Attempt to insert event_id. Fails if exists.
    let insert_result = sqlx::query!(
        "INSERT INTO processed_webhooks (event_id, type) VALUES ($1, $2) ON CONFLICT DO NOTHING",
        event.id, event.type_
    ).execute(&db).await.unwrap();

    if insert_result.rows_affected() == 0 {
        // Event already processed. Return 200 OK immediately.
        tracing::info!("Webhook {} already processed, skipping", event.id);
        return StatusCode::OK;
    }

    // 2. Process Business Logic Safely
    match event.type_.as_str() {
        "invoice.paid" => process_invoice_paid(&db, event).await,
        "customer.subscription.deleted" => revoke_access(&db, event).await,
        _ => {}
    }

    StatusCode::OK
}
```

### SaaS Subscription Data Model (PostgreSQL)

**✅ CORRECT (Local Cache of Gateway State)**
```sql
CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR NOT NULL,
    -- Local cache of the billing provider's state
    stripe_customer_id VARCHAR UNIQUE,
    subscription_status VARCHAR NOT NULL DEFAULT 'trialing', -- active, past_due, canceled, trialing
    subscription_plan_id VARCHAR,
    current_period_end TIMESTAMPTZ,
    cancel_at_period_end BOOLEAN DEFAULT FALSE
);

CREATE TABLE processed_webhooks (
    event_id VARCHAR PRIMARY KEY,
    type VARCHAR NOT NULL,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## 3. Workflow & Best Practices

1.  **Trial to Paid Flow:** Never require a credit card upfront for a SaaS trial if the goal is PLG (Product-Led Growth). Use a `trial_ends_at` column. When the trial ends, transition to a hard paywall.
2.  **Upgrades/Downgrades (Proration):**
    *   **Upgrades:** Always charge immediately and apply proration to capture the value instantly.
    *   **Downgrades:** Apply the downgrade at the *end* of the current billing cycle to avoid complex refunds and angry customers. Set `cancel_at_period_end = true` or schedule the downgrade in the gateway.
3.  **One-to-One Mapping:** Maintain a strict 1:1 mapping between your `tenant_id` and the gateway's `customer_id`. Never allow multiple customers for one tenant unless specifically architected for enterprise parent-child billing.
4.  **Asaas Integration Note:** For Brazilian SaaS, Asaas requires `asaas-access-token` header validation and strictly uses POST webhooks. Always validate the token before processing the event.
