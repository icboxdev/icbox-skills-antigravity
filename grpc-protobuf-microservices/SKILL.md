---
name: gRPC & Protobuf Microservices
description: Validate, generate, and architect High-Performance microservices using gRPC and Protocol Buffers (Protobuf). Enforces HTTP/2 multiplexing, connection pooling, binary serialization, and appropriate Unary vs. Streaming patterns.
---

# gRPC & Protobuf Microservices Engineering

This skill dictates the dogmas for building high-throughput, low-latency internal microservice communication using gRPC and Protocol Buffers.

## 🏛️ Architectural Dogmas

1.  **Internal Backend-to-Backend Standard**: gRPC is the default standard for internal synchronous service-to-service communication. Do NOT use REST/JSON for highly active internal communication paths due to serialization overhead.
2.  **Schema First (Protobuf)**: The `.proto` file is the ultimate source of truth. Both client and server code MUST be generated from this single contract. Never modify generated code manually.
3.  **Connection Pooling / Channel Reuse**: gRPC establishes HTTP/2 connections. Establishing an HTTP/2 connection is expensive. You MUST reuse the `Channel` across multiple calls (multiplexing). NEVER create a new Channel per request.
4.  **Forward/Backward Compatibility**: When evolving a `.proto` schema:
    *   NEVER change the tag number of an existing field.
    *   NEVER change the type of an existing field.
    *   ALWAYS mark deleted fields as `reserved` to prevent future tag reuse.
5.  **Browser Limitations**: Do NOT expose raw gRPC directly to web browsers, as browsers lack native control over HTTP/2 framing. Use a proxy (Envoy with gRPC-Web) or expose REST/GraphQL via an API Gateway that maps to internal gRPC.

## 💻 Implementation Patterns

### CERTO: Protobuf Definition & Evolution
```protobuf
// CERTO: Versioning and reserved fields
syntax = "proto3";
package payments.v1;

service PaymentService {
  rpc ProcessPayment (PaymentRequest) returns (PaymentResponse);
  // Bi-directional streaming for continuous status updates
  rpc StreamPaymentStatus (stream StatusRequest) returns (stream StatusResponse); 
}

message PaymentRequest {
  string user_id = 1;
  double amount = 2;
  
  // 3 was used for credit_card_number, but we moved to PCI tokens.
  // ✅ CERTO: Reserving the tag prevents catastrophic data corruption if an old client connects.
  reserved 3;
  reserved "credit_card_number";
  
  string payment_token = 4;
}
```

### ERRADO: Channel Exhaustion (Rust/Tonic Example)
```rust
// ERRADO: Creating a new channel per request destroys performance
async fn make_payment() {
    // ❌ Re-establishing TLS and HTTP/2 handshake every time
    let mut client = PaymentServiceClient::connect("http://[::1]:50051").await?;
    let request = tonic::Request::new(PaymentRequest { /* ... */ });
    client.process_payment(request).await?;
}
```

### CERTO: Channel Reuse
```rust
// CERTO: Share a cloneable client/channel (it uses an internal connection pool)
use std::sync::Arc;

struct AppState {
    // Tonic clients are cheap to clone because the underlying Channel is shared
    payment_client: PaymentServiceClient<tonic::transport::Channel>,
}

async fn handle_request(state: Arc<AppState>) {
    // ✅ Reuses existing multiplexed HTTP/2 connection
    let mut client = state.payment_client.clone();
    let request = tonic::Request::new(PaymentRequest { /* ... */ });
    client.process_payment(request).await?;
}
```

## 🌊 Streaming Patterns (Server, Client, Bi-Di)

- **Unary**: Standard Request/Response. Use for 95% of use cases.
- **Server Streaming**: Use when downloading massive files or reading large database cursors line-by-line without exhausting RAM.
- **Bi-Directional Streaming**: Use for complex handshakes, continuous chat, or real-time gaming state syncs where both parties send and receive asynchronously on a persistent pipe. Do not overuse simply to replace Unary calls, as Streams are pinned to a single server pod and break standard Layer 7 load balancing.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

