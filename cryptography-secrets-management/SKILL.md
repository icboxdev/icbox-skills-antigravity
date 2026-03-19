---
name: Envelope Encryption & Secrets Management
description: Architect, generate, and validate robust cryptography architectures using Envelope Encryption, AWS KMS, HashiCorp Vault, and AES-GCM for secrets management and data at rest protection.
---

# Envelope Encryption & Secrets Management

This skill dictates the dogmas for protecting sensitive data, preventing plaintext secret spillage, and managing cryptographic key lifecycles at scale in cloud-native applications.

## 🏛️ Architectural Dogmas

1.  **Envelope Encryption is Mandatory**: For Data at Rest, never encrypt large payloads directly with a master key. Generate a temporary Data Encryption Key (DEK), encrypt the data with the DEK via AES-GCM, encrypt the DEK with the Key Encryption Key (KEK) via KMS, and store the encrypted data alongside the encrypted DEK.
2.  **AES-GCM Authenticated Encryption**: Always use AES-256-GCM for symmetric data encryption locally. It provides both confidentiality and data integrity/authenticity.
3.  **IV/Nonce Uniqueness**: When using AES-GCM, the Initialization Vector (IV/Nonce) MUST be cryptographically random and unique for *every single encryption operation*. IV reuse is catastrophic.
4.  **No Hardcoded Secrets**: Credentials, API keys, and connection strings MUST reside in a Secrets Manager (AWS Secrets Manager, HashiCorp Vault) and be injected into memory via environment variables or sidecars at runtime.
5.  **Automatic Key Rotation**: Master keys (KEKs) in the Cloud KMS MUST have automatic rotation enabled (e.g., yearly). Because you use envelope encryption, rotating the KEK does not require re-encrypting the terabytes of data encrypted by the historical DEKs.
6.  **KMS Auto-Unseal**: If using HashiCorp Vault, configure it to auto-unseal using AWS KMS (or equivalent cloud KMS) to eliminate manual intervention and human touch of the unseal keys during node restarts.

## 💻 Implementation Patterns

### CERTO: Envelope Encryption Flow (Node.js Pseudo-code)
```javascript
// CERTO: Envelop Encryption using KMS and AES-GCM
import { KMSClient, GenerateDataKeyCommand } from '@aws-sdk/client-kms';
import crypto from 'crypto';

const kms = new KMSClient({ region: 'us-east-1' });
const CMK_ID = process.env.KMS_KEK_ID;

async function encryptData(plaintextJson) {
  // 1. Ask KMS for a new Data Encryption Key (DEK)
  const command = new GenerateDataKeyCommand({ KeyId: CMK_ID, KeySpec: 'AES_256' });
  const { Plaintext: DEK, CiphertextBlob: EncryptedDEK } = await kms.send(command);

  // 2. Encrypt data locally using the fast plaintext DEK and AES-GCM
  const iv = crypto.randomBytes(12); // GCM standard demands 96-bit (12 bytes) IV
  const cipher = crypto.createCipheriv('aes-256-gcm', DEK, iv);
  
  let encryptedData = cipher.update(JSON.stringify(plaintextJson), 'utf8', 'base64');
  encryptedData += cipher.final('base64');
  const authTag = cipher.getAuthTag().toString('base64');

  // 3. SECURELY ERASE PLAINTEXT DEK FROM MEMORY (Best effort in JS via GC)
  DEK.fill(0); 

  // 4. Store the encrypted payload WITH the encrypted DEK
  return {
    encryptedData,
    iv: iv.toString('base64'),
    authTag,
    encryptedDek: Buffer.from(EncryptedDEK).toString('base64'), // Save KEK-wrapped DEK
  };
}
```

### ERRADO: Cryptographic Anti-Patterns
```javascript
// ERRADO: Direct Master Key Encryption
// ❌ Performance hit and KMS API limits exhausted
// ❌ Makes key rotation impossible for large datasets
const result = await kms.encrypt({ KeyId: CMK, Plaintext: hugeDataPayload });

// ERRADO: Static IVs in AES-GCM
// ❌ IV reuse destroys AES-GCM security instantly
const staticIv = Buffer.from('123456789012'); 
const cipher = crypto.createCipheriv('aes-256-gcm', DEK, staticIv); 
```

## 🔐 Secrets Management Best Practices (Vault / AWS)

- **Dynamic Secrets (Vault)**: Prefer generating temporary, short-lived credentials (e.g., a DB user that expires in 1 hour) instead of long-lived static passwords.
- **Least Privilege IAM**: The IAM Role of the application should only have `kms:Decrypt` and `kms:GenerateDataKey` permissions. It should NOT have admin access to the key policy.
- **Audit Trails**: Ensure AWS CloudTrail or Vault Audit Logging is active. Every decryption of a DEK is an audit event tied to a specific machine identity.
