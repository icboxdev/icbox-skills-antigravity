---
name: WebAuthn, Passkeys & FIDO2
description: Validate, architect, and generate zero-password authentication flows using WebAuthn, Passkeys, and FIDO2 standards. Enforces public-key cryptography, device biometrics integration, fallback mechanisms, and strict origin validation.
---

# WebAuthn, Passkeys & FIDO2 Engineering

This skill dictates the architectural dogmas and best practices for implementing modern, passwordless authentication using WebAuthn and Passkeys (FIDO2/CTAP2 standard).

## 🏛️ Architectural Dogmas

1.  **Zero-Password Goal**: Passkeys MUST be treated as a primary, phishing-resistant authentication method. Do NOT rely on passwords if the user has registered a passkey.
2.  **Public-Key Cryptography (No Shared Secrets)**: The server MUST only store the public key and an associated `credential_id`. The private key MUST never leave the user's authenticator (platform or roaming).
3.  **Strict Origin Binding**: Enforce strict RP (Relying Party) ID and origin validation on the server to prevent Relayed Phishing and Man-in-the-Middle (MitM) attacks.
4.  **Verified Libraries Only**: NEVER "roll your own" WebAuthn crypto/validation logic. Always use established libraries (e.g., `@simplewebauthn/server` for Node, `webauthn-rs` for Rust).
5.  **Graceful Fallbacks**: Always design fallback authentication methods (e.g., email magic links, recovery codes) for instances where the user loses their device/authenticator. SMS is considered a degraded state.
6.  **Biometric Frictionless Flow**: Optimize the user flow to leverage native biometrics (Face ID, Touch ID, Windows Hello) via Platform Authenticators.
7.  **MDS3 for Enterprise**: For enterprise applications, use the FIDO Metadata Service (MDS3) to verify the authenticator's characteristics and enforce hardware-bound keys if necessary.

## 💻 WebAuthn Flow Implementations

### CERTO: Passkey-First UX and Server Validation
```typescript
// CERTO: Using SimpleWebAuthn for secure verification (Node.js/TypeScript)
import { verifyAuthenticationResponse } from '@simplewebauthn/server';
import { getExpectedOrigin, getExpectedRPID } from '@/config/auth';

async function verifyPasskeyLogin(userId: string, body: any) {
  // 1. Retrieve the user's registered public key and current challenge from DB
  const user = await db.users.findById(userId);
  const authenticator = user.authenticators.find(a => a.credentialID === body.id);
  
  if (!authenticator) throw new Error('Authenticator not found');

  // 2. Perform cryptographically secure verification
  let verification;
  try {
    verification = await verifyAuthenticationResponse({
      response: body,
      expectedChallenge: user.currentChallenge,
      expectedOrigin: getExpectedOrigin(), // e.g., 'https://app.example.com'
      expectedRPID: getExpectedRPID(),     // e.g., 'example.com'
      authenticator: {
        credentialPublicKey: authenticator.credentialPublicKey,
        credentialID: authenticator.credentialID,
        counter: authenticator.counter,
      },
    });
  } catch (error) {
    throw new Error(`Verification failed: ${error.message}`);
  }

  const { verified, authenticationInfo } = verification;

  if (verified) {
    // 3. Update the counter to prevent replay attacks
    await db.authenticators.update(authenticator.id, {
      counter: authenticationInfo.newCounter
    });
    
    // 4. Issue session cookie
    return issueSessionCookie(user.id);
  }
  
  throw new Error('Verification failed');
}
```

### ERRADO: Insecure Implementations
```typescript
// ERRADO: Rolling own validation or ignoring Origin/Replay checks
function verifyLogin(body) {
  // ❌ Vulnerable to Phishing: Not verifying RP ID or Origin
  // ❌ Vulnerable to Replay: Not checking/updating the signature counter
  // ❌ Fragile: Direct crypto parsing without a verified library
  const isValid = myCustomCryptoCheck(body.signature, body.clientDataJSON);
  return isValid; 
}
```

## 🧠 Best Practices for 2024-2025

- **Conditional UI (Autofill)**: Implement Conditional UI in inputs (`autocomplete="webauthn"`) to allow browsers to automatically prompt passkeys when the user focuses on a login field.
- **Multiple Credentials**: Prompt users to register multiple devices (e.g., Phone + Laptop) to avoid account lockout.
- **Attestation vs Assertion**: Use "none" for attestation in consumer apps to maximize privacy and registration success. Use "direct" or "enterprise" attestation ONLY when strict hardware compliance is required by security policy.
- **User Presence vs User Verification**: `userVerification: 'preferred'` or `'required'` ensures biometrics/PIN is used, conferring MFA properties in a single step.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

