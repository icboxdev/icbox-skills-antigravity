---
name: B2B Enterprise SaaS Architecture
description: Architect, secure, and validate B2B Enterprise SaaS applications covering SSO/SAML integrations, SCIM provisioning, Tenant Isolation models, Audit Logging, Data Residency compliance, and enterprise SLAs.
---

# B2B Enterprise SaaS Architecture Mastery

This skill enforces the architectural patterns required to sell software to Chief Information Security Officers (CISOs) at large enterprises. Enterprise B2B SaaS requires vastly different capabilities than standard B2C or SMB SaaS.

## ZERO-TRUST & ENTERPRISE RULES
*   **The Enterprise Controls Identity:** In B2B, the customer's IT department is the source of truth for identity, not your app. You MUST support federation (SSO).
*   **Auditability is Mandatory:** "Who did what, when, and from where" must be immutably recorded for compliance (SOC 2, ISO 27001, HIPAA).
*   **Tenant Isolation is Paramount:** A cross-tenant data leak is an extinction-level event for a SaaS company. Isolation must be mathematically provable (e.g., RLS).

## 1. Core Enterprise Features

### SSO (Single Sign-On) & SAML/OIDC
*   Enterprises refuse to manage separate passwords. Your application must act as a Service Provider (SP) trusting an Identity Provider (IdP) like Okta, Azure AD, or Google Workspace.
*   Support Just-In-Time (JIT) provisioning upon successful SAML assertion, but prefer SCIM for lifecycle management.
*   **SAML Security:** Enforce strict signature validation, audience restriction, and assertion expiration times to prevent replay attacks.

### SCIM (System for Cross-domain Identity Management)
*   SSO handles *Authentication* (Login). SCIM handles *Provisioning Lifecycle* (Creation, Updates, Deactivation).
*   When an employee leaves the enterprise, IT disables them in Active Directory. SCIM pushes a `DELETE` or `PATCH (active: false)` request to your SaaS proactively, instantly terminating access before the user attempts a login.
*   Implement standard SCIM 2.0 endpoints (`/scim/v2/Users`, `/scim/v2/Groups`).

### Audit Logging (Event Sourcing for Security)
*   **Immutability:** Audit logs must be append-only. No UPDATEs or DELETEs allowed.
*   **Context:** Every mutation (Create/Update/Delete) and sensitive read (e.g., exporting a customer list) MUST log:
    *   `actor_id` (User who did it)
    *   `action` (e.g., `user.deleted`, `settings.updated`)
    *   `resource_type` & `resource_id`
    *   `diff` or `metadata` (What changed, e.g., `{"old": "admin", "new": "manager"}`)
    *   `ip_address` & `user_agent`
    *   `tenant_id` (Crucial for querying by customer)

### Tenant Isolation Models
1.  **Silo (Database per Tenant):** Highest isolation, highest cost.
2.  **Pool (Shared Schema with `tenant_id`):** Lowest cost, hardest to secure (Requires strict RLS and middleware).
3.  **Bridge (Schema per Tenant):** Postgres `CREATE SCHEMA tenant_abc`. A strong middle ground for B2B.
*   *Rule:* Always explicitly document the chosen model in `AI.md`. If Pool is chosen, PostgreSQL Row-Level Security (RLS) is strictly required.

### Data Residency & Compliance
*   **GDPR (EU) / LGPD (BR) / PDPL (Saudi):** Data must physically reside in specific geographic zones.
*   Architect the application so the execution path (Compute + Storage) can be deployed in isolated regional clusters (e.g., `eu-west-1` vs `sa-east-1`).
*   Global routing tables (or subdomain routing) direct the tenant to their specific regional deployment.

## 2. Few-Shot Examples

### Audit Log Schema (PostgreSQL)

**✅ CORRECT (Immutable Audit Log)**
```sql
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    actor_id UUID NOT NULL REFERENCES users(id),
    action VARCHAR NOT NULL, -- e.g., 'invoice.created'
    resource_type VARCHAR NOT NULL, -- e.g., 'invoice'
    resource_id UUID NOT NULL,
    -- Store the delta or full snapshot
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    ip_address INET,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Optimization: Enterprises will want reports of the last 90 days.
CREATE INDEX idx_audit_logs_tenant_created ON audit_logs(tenant_id, created_at DESC);
CREATE INDEX idx_audit_logs_actor ON audit_logs(actor_id);
```

### SCIM Provisioning API Endpoint (Node.js/Express)

**✅ CORRECT (SCIM User Deactivation)**
```typescript
// SCIM 2.0 requests are authenticated via a Tenant-specific Bearer Token
router.patch('/scim/v2/Users/:id', scimAuthMiddleware, async (req, res) => {
    const { id } = req.params;
    const { Operations } = req.body; // SCIM uses PATCH Operations array

    for (const op of Operations) {
        if (op.op === 'replace' && op.path === 'active') { // Standard deactivation
            const isActive = op.value;
            if (!isActive) {
                // Instantly sever all active sessions & disable
                await revokeAllUserSessions(id);
                await db.users.update({ id }, { status: 'DEACTIVATED' });
                
                // Log for compliance
                await auditLog.insert({
                    actorId: req.scimSystemId,
                    action: 'user.scim.deactivated',
                    resourceId: id,
                });
            }
        }
    }
    
    // Respond with the updated SCIM User representation
    const updatedUser = await buildScimUserPayload(id);
    return res.status(200).json(updatedUser);
});
```

## 3. Workflow & Best Practices
1. **Design for Custom Domains:** Support `login.customer.com` by handling SNI routing and SSL certificate provisioning dynamically.
2. **Rate Limiting by Tenant, not just IP:** Enterprise customers behind a NAT gateway will share IPs. Rate limit based on the `tenant_id` associated with their API Key or Session to prevent noisy neighbor problems.
3. **RBAC is rarely enough:** Enterprises need ABAC (Attribute-Based Access Control) or custom role creation. Allow them to define policies like "Can view invoices IF invoice.region == 'EU'".
