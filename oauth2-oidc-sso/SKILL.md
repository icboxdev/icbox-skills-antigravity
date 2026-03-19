---
name: OAuth 2.1, OIDC & Enterprise SSO
description: Architect and validate authentication flows using OAuth 2.1, OpenID Connect (OIDC), and SAML. Enforces mandatory PKCE, removal of Implicit Grant, strict redirect URIs, and secure Identity Broker architectures.
---

# OAuth 2.1, OIDC & Enterprise SSO Engineering

This skill dictates the architectural dogmas for modern distributed authentication, enforcing OAuth 2.1 standards, OIDC for identity, and enterprise SSO patterns (SAML/Keycloak).

## 🏛️ Architectural Dogmas (OAuth 2.1 Standard)

1.  **PKCE is Mandatory**: Proof Key for Code Exchange (PKCE) is REQUIRED for ALL clients (both public and confidential) using the Authorization Code grant. This prevents authorization code injection.
2.  **No Implicit Grant**: The Implicit Grant and Resource Owner Password Credentials (ROPC) grant are strictly PROHIBITED. Always use Authorization Code flow with PKCE.
3.  **Strict Redirect URIs**: Exact string matching is required for redirect URIs. Wildcards or partial matches are forbidden to prevent token leakage.
4.  **OIDC for Identity**: Use OpenID Connect (OIDC) via the `id_token` for verifying user identity, NOT raw OAuth access tokens, which are designed for API authorization.
5.  **Token Storage Security**: Access and Refresh tokens MUST be stored securely. In browser environments (SPA), prefer Backend-for-Frontend (BFF) patterns with `HttpOnly`, `SameSite=Strict` cookies over `localStorage` (XSS vulnerable).
6.  **Refresh Token Rotation**: If refresh tokens are issued to public clients (SPAs/Mobile), they MUST employ token rotation and reuse detection to mitigate token theft.

## 💻 Implementation Patterns

### CERTO: OAuth 2.1 Auth Code Flow with PKCE (Frontend Side)
```typescript
// CERTO: PKCE Implementation in SPA (Standard OAuth 2.1)
import { generateCodeVerifier, generateCodeChallenge } from './crypto-utils';

async function initiateLogin() {
  const codeVerifier = generateCodeVerifier();
  const codeChallenge = await generateCodeChallenge(codeVerifier);
  
  // Store verifier in sessionStorage to be used after redirect
  sessionStorage.setItem('pkce_verifier', codeVerifier);
  
  const authUrl = new URL('https://auth.example.com/oauth2/authorize');
  authUrl.searchParams.append('response_type', 'code'); // NEVER 'token'
  authUrl.searchParams.append('client_id', 'spa-client-123');
  authUrl.searchParams.append('redirect_uri', 'https://app.example.com/callback'); // Exact match
  authUrl.searchParams.append('scope', 'openid profile offline_access');
  authUrl.searchParams.append('code_challenge', codeChallenge);
  authUrl.searchParams.append('code_challenge_method', 'S256'); // Mandatory in OAuth 2.1
  
  window.location.href = authUrl.toString();
}
```

### ERRADO: Vulnerable OAuth 2.0 Patterns
```typescript
// ERRADO: Implicit Grant Flow 
const insecureUrl = `https://auth.com/authorize?response_type=token&client_id=123`; // ❌ Forbidden by OAuth 2.1

// ERRADO: Missing PKCE for Authorization Code
const weakUrl = `https://auth.com/authorize?response_type=code&client_id=123`; // ❌ Lack of PKCE allows Code Injection
```

## 🏢 Enterprise SSO & IAM Brokers

When building B2B SaaS, direct integration with thousands of Identity Providers (IdPs) is impossible.

1.  **Identity Broker Pattern**: Use an Identity Broker (e.g., Auth0, Keycloak, authentik) to abstract identity. Your app talks OIDC to the Broker; the Broker talks SAML/OIDC to the enterprise tenants (Azure AD, Okta, Google Workspace).
2.  **JIT Provisioning (Just-in-Time)**: Map SAML Assertions or OIDC Claims to your local user database attributes upon successful login.
3.  **Tenant Mapping**: Rely on the `iss` (Issuer) and `email` domain claims from the IdP to map users correctly to their respective Multi-Tenant organizations.
