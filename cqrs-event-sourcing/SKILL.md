---
name: CQRS & Event Sourcing Architecture
description: Architect, generate, and validate enterprise-scale CQRS and Event Sourcing patterns. Enforces Command/Query segregation, append-only immutable Event Stores, asynchronous read-model projections, and snapshotting for hydration performance.
---

# 🔄 CQRS & Event Sourcing Mastery

This skill defines the architectural dogmas and absolute best practices for building hyper-scalable, fully auditable, and resilient systems using **CQRS (Command Query Responsibility Segregation)** and **Event Sourcing**.

## 🏗️ Core Architectural Dogmas

### 1. The Append-Only Event Store (Source of Truth)
*   **Dogma:** State is NEVER UPDATED in place. Every state change mathematically equals evaluating an ordered sequence of immutable events.
*   **Rule:** The database storing the Domain Events (The Event Store) must be append-only. No `UPDATE`, no `DELETE`.
*   **Technologies:** Use dedicated event stores like **EventStoreDB**, or configure relational databases (PostgreSQL) strictly for append-only tables. While Kafka is great for event *streaming*, it is generally NOT an Event Store unless using Infinite Retention topics (which can be hard to query by Aggregate ID).

### 2. Strict C/Q Segregation
*   **Dogma:** The Command Stack (Writes) and the Query Stack (Reads) MUST be entirely separate models, and ideally, separate physical databases/services.
*   **Commands:** Execute business logic, validate invariants, and append events to the Event Store. They DO NOT return data (beyond an ID or ACK).
*   **Queries:** Read perfectly shaped, denormalized data directly from a Read Model (Projection). They execute instantly. They DO NOT mutate state.

## ⚙️ The Mechanics of Event Sourcing

### 1. Projections (Building the Read Model)
*   **Rule:** When a Command appends an Event (e.g., `OrderPlaced`), an asynchronous projector listens for this event and updates a heavily denormalized Read Database (e.g., Elasticsearch, MongoDB, or a flattened PostgreSQL table) specifically tailored for a UI screen.
*   **Dogma:** Projections are ephemeral. You must be able to drop the Read Database completely, replay all events from the Event Store from the beginning of time, and perfectly rebuild the Read Model.

### 2. Aggregates & Event Rehydration
*   **Rule:** Before a Command can evaluate business logic, it must load the current state of the Entity (Aggregate). It does this by loading all past events for that Aggregate ID and folding (reducing) them sequentially.
*   **Optimization (Snapshotting):** If an Aggregate has 10,000 events, rehydration is slow. Implement Snapshots: periodically save the folded state (e.g., every 100 events). To rehydrate, load the latest Snapshot + any events that occurred *after* the Snapshot timestamp.

## 🔒 Consistency and Versioning

### 1. Eventual Consistency Acceptance
*   **Dogma:** CQRS + Event Sourcing implies **Eventual Consistency**. The UI might execute a command and immediately query the read model, but the read model might not reflect the change for a few milliseconds.
*   **Rule:** The Frontend MUST be designed to handle this (e.g., Optimistic UI updates, or long-polling/WebSockets waiting for the server to acknowledge the projection is complete).

### 2. Event Versioning (Upcasting)
*   **Dogma:** Events are forever. You cannot change a past event's schema.
*   **Rule:** If a business requirement changes the shape of an event (e.g., `UserCreated_v1` -> `UserCreated_v2`), the Event Store must implement an "Upcaster" — a middleware that intercepts `v1` events during read-time and maps them to `v2` on the fly, before hitting the Domain logic.

## 🚨 Anti-Patterns (DO NOT DO THIS)

*   ❌ **NEVER** use Event Sourcing for generic CRUD applications. The complexity overhead is massive. Use it ONLY for core business domains where the audit trail, point-in-time recovery, or extreme read/write asymmetric scalability is absolutely crucial (e.g., accounting ledgers, high-frequency trading, complex logistics).
*   ❌ **NEVER** store PII (Personally Identifiable Information) directly inside immutable events if you must comply with GDPR/LGPD "Right to be Forgotten". Use Crypto-Shredding: encrypt PII in the event payload using a tenant/user-specific encryption key, and "delete" the user by throwing away their encryption key.
*   ❌ **NEVER** let the Read Model dictate the Event schema. Events are domain facts, not UI data structures.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

