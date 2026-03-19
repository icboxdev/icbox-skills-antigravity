---
name: Customer Success & Helpdesk Architecture
description: Architect, generate, and validate B2B Customer Success and Helpdesk platforms. Enforces Ticket Routing algorithms, strict SLA (Service Level Agreement) enforcement engines, Omnichannel Threading, and multi-tenant isolation.
---

# 🎧 Customer Success & Helpdesk Architecture Mastery

This skill defines the architectural dogmas and absolute best practices for building scalable B2B **Helpdesk**, Support Ticketing, and **Customer Success (CS)** platforms.

## 🏗️ Core Architectural Dogmas

### 1. Omnichannel Threading
*   **Dogma:** An agent must not care whether a message came from WhatsApp, Email, or Web Widget. The domain model must normalize conversations into a unified "Ticket Thread".
*   **Rule:** Implement a polymorphic `messages` table/collection within a `tickets` aggregate. Each message tracks its `source_channel` and `external_id`.
*   **Rule:** Outbound replies from the agent are dispatched to an event bus (`EventBus.publish('MessageSent', payload)`), and a dedicated routing worker delivers it back to the original channel (e.g., via WAHA API for WhatsApp or SendGrid for Email).

### 2. SLA Engine (Service Level Agreement)
*   **Dogma:** SLAs are not simple `created_at + 2 hours`. SLAs rely on complex Business Hours and Statuses.
*   **Rule:** The SLA engine MUST account for:
    *   **Business Hours:** A ticket opened Friday at 17:50 with a 2-hour SLA should breach Monday morning, not Friday night.
    *   **Pause States:** When a ticket is "Waiting for Customer", the SLA clock MUST pause. It resumes when the customer replies.
*   **Rule:** Use a CRON/Worker system or highly optimized materialized views to track SLA Warning thresholds (e.g., 80% consumed) to trigger escalation webhooks.

### 3. Ticket Routing Algorithms
*   **Dogma:** Do not rely solely on agents manually "cherry-picking" tickets from a global backlog.
*   **Rule:** Implement Automated Ticket Routing with priority weighting:
    1.  **Skill-Based:** Issue "Technical" goes to specific agent pools.
    2.  **Load-Balanced (Round Robin):** Find the online agent in the pool with the fewest active tickets.
    3.  **VIP/Tenant Tiering:** Tickets from "Enterprise" tenants bypass queues.

## ⚙️ Data and Event Sourcing

### 1. The Audit Log (Ticket History)
*   **Dogma:** Every state transition in a Helpdesk MUST be perfectly auditable. "Who changed the priority? When did the SLA breach?"
*   **Rule:** Implement an Event Sourcing approach or an append-only `ticket_events` table.
*   **Rule:** The frontend UI must be able to render a combined timeline showing both text messages AND system events (e.g., `[System] Agent John merged this ticket with #1024`).

### 2. Multi-Tenant Database Optimization
*   **Dogma:** Helpdesks can generate millions of rows (chat messages).
*   **Rule:** For B2B platforms, enforce strict Row-Level Security (RLS) or partition tables by `tenant_id` so large enterprise tenants do not destroy query performance for smaller tenants. If using PostgreSQL, consider `PARTITION BY LIST (tenant_id)`.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

