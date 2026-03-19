---
name: API Gateway (Kong & Tyk) Management
description: Architect, generate, and validate edge traffic management utilizing API Gateways like Kong or Tyk. Enforces Centralized Rate Limiting (Redis-backed), Ingress routing, API Key lifecycle, and OWASP Edge mitigation.
---

# API Gateway (Kong & Tyk) Management

This skill dictates the dogmas for deploying API Gateways as the single entry point (Edge) for microservice architectures.

## 🏛️ Architectural Dogmas

1.  **Centralized Edge Tier (Tier 2)**: All inbound external traffic MUST pass through an API Gateway. Microservices MUST NOT be directly exposed to the internet.
2.  **Cross-Cutting Concerns Offloading**: The Gateway is responsible for cross-cutting security concerns: TLS termination, IP Whitelisting, Rate Limiting, CORS, and basic API Key validation. Do NOT reinvent these in every underlying microservice.
3.  **Distributed Rate Limiting**: Limit policies (Fixed Window, Sliding Window, Token Bucket) MUST be enforced globally across all Gateway instances. This requires the Gateway to connect to a centralized Redis cluster to aggregate request counts. Memory-local rate limiting is useless in multi-pod deployments.
4.  **Backend Agnosticism**: The Gateway acts as a reverse proxy. The underlying services can migrate from Node.js to Rust without the client ever knowing, as the Gateway handles the exterior API contract and routing.

## ⚖️ Kong vs Tyk Paradigms

- **Kong**: Written in Lua over NGINX (OpenResty). Extremely fast for high RPS routing. Configuration is heavily plugin-based (Community vs Enterprise). Ideal for teams with deep NGINX experience.
- **Tyk**: Written in Go. "Batteries-included" approach with a powerful built-in dashboard and analytics out of the open-source box. Ideal for Kubernetes-native environments and complex policy aggregation.

## 💻 Implementation Patterns

### CERTO: Kong Declarative Config (decK)
```yaml
# CERTO: Infrastructure as Code for API Gateway routing and rate-limiting
_format_version: "3.0"
services:
  - name: internal-payment-service
    url: http://payments-ms:8080
    routes:
      - name: payment-route
        paths:
          - /api/v1/payments
    plugins:
      # ✅ Centralized Redis-backed Rate Limiting
      - name: rate-limiting
        config:
          minute: 100
          limit_by: ip
          policy: redis
          redis_host: redis-cluster.internal
          fault_tolerant: true # If Redis dies, fail open (allow traffic)
          hide_client_headers: false # Return Retry-After headers to client
```

### ERRADO: Decentralized Anti-Pattern
```typescript
// ERRADO: Implementing IP Rate Limiting inside the specific Microservice
// ❌ Wastes backend CPU on malicious DDoS bots.
// ❌ Requires repeating this code in the Rust service, the Python service, etc.
app.use(rateLimit({
  windowMs: 15 * 60 * 1000, 
  max: 100,
  standardHeaders: true, 
}))
```

## 🧠 Best Practices (2024-2025)

- **Graceful Degradation (Fail Open vs Fail Closed)**: If the Redis rate-limiting backend crashes, the API Gateway plugin MUST be configured to "fail open" (allow traffic but alert). Blocking all traffic because a metrics database died is an architectural failure.
- **Shadow APIs Mitigation**: The Gateway should enforce strict routing based on an OpenAPI 3.0 specification. Any path requested by a client that does not exist in the Gateway route map MUST be dropped at the Edge with a `404` or `403`.
- **Throttling vs Quotas**: 
  - *Throttling*: Short-term protection (e.g., 5 Req/Sec) to prevent micro-burst DDoS.
  - *Quotas*: Long-term commercial limits (e.g., 10,000 Req/Month) tied to billing. The Gateway should handle both through different plugin layers.
