---
name: WAF, Bot Protection & API Security
description: Architect and validate external API perimeters enforcing Cloudflare Turnstile, Edge Rate Limiting, WAF Rules, OWASP API Top 10 mitigation, and Bot behavior scoring.
---

# WAF, Bot Protection & API Security Architecture

This skill dictates the architectural dogmas for defending web applications and APIs against malicious bots, automated attacks, and resource exhaustion utilizing Edge firewalls (WAF) and modern token mechanisms like Cloudflare Turnstile.

## 🏛️ Architectural Dogmas (Two-Tier Defense)

A resilient API MUST implement a Two-Tier security architecture to protect origin servers.

1.  **Tier 2 (Edge Defense - WAF)**:
    *   **Action**: Block obvious threats at the CDN/Edge before they reach the backend CPU or DB.
    *   **Mechanisms**: Cloudflare WAF (OWASP core rulesets), Managed IP Reputation blocks, Layer 7 DDoS mitigation, and Global Rate Limiting based on IP/Path combinations.
    *   **Bot Management**: Utilize ML-driven Bot Scores attached to headers to drop `Likely Bot` traffic at the edge.
2.  **Tier 1 (Application Logic - Backend)**:
    *   **Action**: Enforce business logic quotas and complex authorization.
    *   **Mechanisms**: Token-bucket or sliding-window rate limiting per `tenant_id` or `user_id` (via Redis), Role-Based Access Control, and Payload validation (Zod/Pydantic).

## 🛡️ Cloudflare Turnstile (CAPTCHA Replacement)

1.  **Invisible Validation**: Turnstile MUST be preferred over traditional reCAPTCHA. It relies on telemetry and hardware signals (V8 isolate analysis) rather than frustrating visual puzzles.
2.  **Server-Side Validation**: Implementing the JS widget on the frontend is insufficient. The backend MUST validate the Turnstile token against the Cloudflare `/siteverify` endpoint before processing any high-risk form (Login, Registration, Checkout).

### CERTO: Turnstile Validation (Backend)
```typescript
// CERTO: Validating Turnstile Token on critical actions
async function loginUser(req, res) {
  const { cfToken, email, password } = req.body;

  // 1. Validate Token First (Fail Early)
  const cfResponse = await fetch('https://challenges.cloudflare.com/turnstile/v0/siteverify', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `secret=${process.env.CF_TURNSTILE_SECRET}&response=${cfToken}`
  });
  
  const verification = await cfResponse.json();
  if (!verification.success) {
    return res.status(403).json({ error: 'Bot verification failed.' });
  }

  // 2. Proceed with computationally expensive password hashing compare
  const user = await db.users.find({ email });
  // ...
}
```

## 🛑 Rate Limiting Strategies

1.  **Unauthenticated APIs (Public)**: Rate limit severely based on IP Address using Edge WAF. (e.g., 5 requests per minute for a login route).
2.  **Authenticated APIs**: Rate limit based on the Customer/Tenant Identifier (JWT claim) to prevent noisy neighbor problems in multi-tenant architectures.
3.  **Headers**: Always return standardized rate-limit headers: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, and `Retry-After`.

## 🕸️ OWASP API Security 2023/2024 Alignment

- **BOLA (Broken Object Level Authorization)**: ID checks MUST be made against the authenticated user ownership, not just existence in the database.
- **Unrestricted Resource Consumption**: Enforce strict pagination limits (`max=100`), timeout constraints on DB queries, and max payload size limits (`client_max_body_size`) to prevent ReDoS or Memory Exhaustion.
- **Improper Inventory Management**: Block "Shadow APIs". Ensure API Gateways enforce strict schema validation for all incoming traffic routes. Traffic not matching a valid Swagger/OpenAPI spec MUST be dropped.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

