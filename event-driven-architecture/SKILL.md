---
name: Event-Driven Architecture & Messaging
description: Architect, generate, and validate Event-Driven Architectures (EDA) enforcing Pub/Sub patterns, Outbox Pattern for atomicity, Idempotent consumers, Dead Letter Queues (DLQ), and distributed Saga transactions.
---

# Event-Driven Architecture (EDA) & Messaging

This skill enforces best practices for asynchronous, decoupled, and scalable systems using message brokers (Kafka, RabbitMQ, SQS, Redis PubSub). It specifically targets the challenges of distributed transactions and guaranteed event delivery.

## ZERO-TRUST & ARCHITECTURAL RULES
*   **NEVER Dual-Write:** NEVER update a database and publish a message directly in the same application logic block without a distributed transaction mechanism. Networks fail. Use the **Outbox Pattern**.
*   **Assume At-Least-Once Delivery:** Message brokers guarantee that a message will be delivered *at least* once. Consequently, duplicate messages WILL happen.
*   **Idempotent Consumers are Mandatory:** Every event handler MUST be idempotent. Processing the same message twice must yield the exact same system state as processing it once.

## 1. Core Dogmas

### The Outbox Pattern (Guaranteed Publishing)
*   **Problem:** You need to update a `User` record in PostgreSQL and publish a `UserCreated` event to Kafka. If the DB commits but Kafka is down, the system is inconsistent.
*   **Solution:** Write the event payload to an `outbox_events` table within the SAME relational database transaction that updates the `User` record.
*   **Publisher:** A separate background worker (or CDC tool like Debezium) reads the `outbox_events` table, publishes the message to the broker, and marks it as sent. Atomicity is guaranteed.

### Dead Letter Queues (DLQ) & Polling
*   Messages that fail processing due to hard errors (parsing errors, missing required data) MUST NOT block the queue indefinitely.
*   Configure max retries (e.g., 3-5 times with exponential backoff). After exhaustion, move the message to a Dead Letter Queue (DLQ).
*   Create automated alerts for the DLQ so engineers can inspect bounded messages, fix the bug, and replay the message ("Redrive").

### Saga Pattern (Distributed Transactions)
*   Used when a business process spans multiple independent microservices which cannot share an ACID transaction.
*   **Choreography:** Services publish events and react to events independently (Good for simple workflows, 2-4 services).
*   **Orchestration:** A central coordinator service tells participants what to do via commands and tracks the total state (Good for complex workflows like E-commerce checkout).
*   **Compensating Transactions:** Every step in a Saga MUST have a corresponding compensating action to revert it if a subsequent step fails (e.g., if "Reserve Inventory" succeeds but "Process Payment" fails, you must invoke "Release Inventory").

## 2. Few-Shot Examples

### Implementing the Outbox Pattern (Rust / SQLx)

**❌ INCORRECT (Dual-Write Anti-Pattern)**
```rust
async fn create_user(pool: &PgPool, rabbit: &Channel, user_data: CreateUserDto) -> Result<()> {
    // 1. Save to DB
    sqlx::query!("INSERT INTO users (name) VALUES ($1)", user_data.name)
        .execute(pool).await?;

    // 2. ERROR: If RabbitMQ is down, the user exists but the event is lost forever!
    rabbit.publish("events", "user.created", "User payload").await?;
    
    Ok(())
}
```

**✅ CORRECT (Outbox Pattern within a Transaction)**
```rust
async fn create_user(pool: &PgPool, user_data: CreateUserDto) -> Result<()> {
    // 1. Start Transaction
    let mut tx = pool.begin().await?;

    // 2. Save Business Entity
    let user_id = sqlx::query!("INSERT INTO users (name) VALUES ($1) RETURNING id", user_data.name)
        .fetch_one(&mut *tx).await?.id;

    let event_payload = serde_json::to_value(&user_data)?;

    // 3. Save Outbox Event (in the SAME transaction)
    sqlx::query!(
        "INSERT INTO outbox_events (aggregate_type, aggregate_id, type, payload) VALUES ($1, $2, $3, $4)",
        "User", user_id, "UserCreated", event_payload
    )
    .execute(&mut *tx).await?;

    // 4. Commit - Either both succeed, or neither do. Atomicity guaranteed.
    tx.commit().await?;

    // Note: A separate background worker will poll `outbox_events` and publish to RabbitMQ.
    Ok(())
}
```

### Idempotent Event Consumer (Node.js)

**✅ CORRECT (Idempotency Key Check)**
```typescript
async function handleOrderCreatedEvent(event: OrderCreatedEvent) {
  // 1. Extract unique idempotency key (e.g., event ID)
  const eventId = event.metadata.eventId;

  return await db.transaction(async (trx) => {
    // 2. Try to insert event ID. Fail gracefully if it already exists.
    const isNew = await trx('processed_events')
      .insert({ id: eventId })
      .onConflict('id')
      .ignore(); // MySQL/PostgreSQL feature

    if (isNew.rowCount === 0) {
      console.log(`Skipping duplicate event: ${eventId}`);
      return; // Already processed
    }

    // 3. Process business logic safely
    await processOrderFulfillment(event.data, trx);
  });
}
```

## 3. Recommended Tech Stack Patterns
1. **Brokers:** Kafka (high throughput, replayable logs), RabbitMQ (advanced routing, DLQs built-in), SQS+SNS (AWS serverless standard). Redis PubSub is acceptable ONLY for transient real-time state (WebSockets), never for durable business events.
2. **Event Schemas:** Use strict schema definitions (JSON Schema, Avro, Protobuf) for events. An event is a public API contract; you cannot break it without versioning.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

