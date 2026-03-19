---
name: RabbitMQ Advanced Routing
description: Architect, generate, and validate asynchronous messaging topologies using RabbitMQ. Enforces Exchange types (Direct, Topic, Fanout), Dead Letter Queues (DLQ), TTL-based Retry Backoff, and Quorum queues for High Availability.
---

# RabbitMQ Advanced Routing Engineering

This skill dictates the dogmas for building resilient, asynchronous, and reliable messaging pipelines using RabbitMQ.

## 🏛️ Architectural Dogmas

1.  **Never Publish Directly to a Queue**: Producers MUST publish messages to `Exchanges`, not directly to queues. This allows the topology (who receives what) to evolve without changing the producer code.
2.  **Exchange Topologies**:
    *   **Direct**: Use for point-to-point tasks (e.g., `routing_key: "pdf_generator"`).
    *   **Fanout**: Use for broadcasting state changes (Pub/Sub) where every bound queue gets a copy (e.g., `user_updates`, where caching service, search service, and email service all listen).
    *   **Topic**: Use for wildcard-based pub/sub patterns (e.g., `routing_key: "audit.user.login"`, where queue binds to `audit.*.*`). 
3.  **Mandatory Dead Letter Queues (DLQ)**: EVERY operational queue MUST have a corresponding DLQ configured via policy (`x-dead-letter-exchange`). Unprocessable messages (exceptions, malformed parsing) MUST be negatively acknowledged (`nack`) with `requeue=false` to send them to the DLQ.
4.  **Retry with Exponential Backoff (TTL pattern)**: For transient errors (e.g., external API down), implement a retry queue with a `message-ttl` and a DLX pointing back to the main queue. The message sleeps in the wait queue, dies, and is dead-lettered back to the active queue for reprocessing.
5.  **Quorum Queues for HA**: For financial or critical data, default to Quorum Queues (Raft consensus) rather than Classic mirrored queues.

## 💻 Implementation Patterns

### CERTO: Retry Backoff Topology (Policy vs Arguments)
```yaml
# CERTO: Define routing topologies logically. 
# Best practice is to set DLX via vhost policies, but here is the architectural flow:

exchanges:
  - name: "work.exchange"
    type: "direct"
  - name: "retry.exchange"
    type: "direct"
  - name: "dlq.exchange"
    type: "direct"

queues:
  - name: "worker.queue"
    arguments:
      x-dead-letter-exchange: "dlq.exchange" # Absolute failures go here
      x-dead-letter-routing-key: "fatal"
      
  - name: "retry.wait.queue"
    arguments:
      x-message-ttl: 30000 # Wait 30 seconds
      x-dead-letter-exchange: "work.exchange" # Send back to main work exchange when TTL dies
      x-dead-letter-routing-key: "process"

bindings:
  - exchange: "work.exchange"
    queue: "worker.queue"
    routing_key: "process"
```

### ERRADO: Infinite Loop Anti-Pattern
```python
# ERRADO: Requeuing infinitely on error destroys broker resources
def callback(ch, method, properties, body):
    try:
        process_payment(body)
        ch.basic_ack(delivery_tag=method.delivery_tag)
    except APIError:
        # ❌ Setting requeue=True on a persistent error creates an infinite spin-loop,
        # maxing out CPU and preventing other messages from processing.
        ch.basic_nack(delivery_tag=method.delivery_tag, requeue=True) 
```

### CERTO: Nacking to DLQ or Retry
```python
def callback(ch, method, properties, body):
    try:
        process(body)
        ch.basic_ack(delivery_tag=method.delivery_tag)
    except TransientAPIError:
        # ✅ Publish to Retry Exchange, then ACK the original so it leaves this queue
        ch.basic_publish(exchange='retry.exchange', routing_key='retry', body=body)
        ch.basic_ack(delivery_tag=method.delivery_tag)
    except FatalValidationError:
        # ✅ Nack with requeue=False sends it to x-dead-letter-exchange immediately
        ch.basic_nack(delivery_tag=method.delivery_tag, requeue=False)
```

## 🧠 Best Practices (2024-2025)
- **Idempotency**: Message redelivery can and will happen (At-Least-Once delivery). Consumers MUST be idempotent. Check the database if a message ID has already been successfully processed before acting.
- **Prefetch Count (QoS)**: Always set a sensible `prefetch_count` (e.g., 10-50). If left at default (unlimited), RabbitMQ pushes millions of messages into RAM of a single slow worker, crashing it via OOM.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

