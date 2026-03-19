---
name: OWASP Security Audit
description: Validate, audit, and enforce web application security following OWASP Top 10 2024, covering broken access control, injection prevention, cryptographic failures, security headers, SAST/DAST tools, and automated security checklist patterns.
---

# OWASP Security Audit — Top 10, Headers, Checklist & Automation

## 1. Propósito

Auditar e reforçar a segurança de aplicações web seguindo OWASP Top 10 2024. Cobre broken access control, injection, criptografia, headers de segurança, e checklist automatizado para frontend e backend.

## 2. Dogmas Arquiteturais

### Defense in Depth

**NUNCA** confiar em uma única camada de segurança. Validar no client E no server. Autenticar E autorizar. Criptografar em trânsito E em repouso.

### Zero Trust Input

**NUNCA** confiar em dados do cliente. TODO input é potencialmente malicioso. Sanitizar, validar e escapar TUDO.

### Least Privilege

**SEMPRE** dar o mínimo de permissões necessárias. API keys com escopo, DB users com grants limitados, RBAC granular.

### Fail Secure

Quando algo falha, **SEMPRE** negar acesso por padrão. Nunca falhar em estado aberto.

## 3. OWASP Top 10 — 2024

### A01: Broken Access Control

```typescript
// CERTO — Verificar ownership no servidor
async function getDocument(req: Request, docId: string) {
  const doc = await db.document.findUnique({ where: { id: docId } });
  if (!doc) throw new NotFoundError();
  if (doc.tenantId !== req.user.tenantId) throw new ForbiddenError();  // ← Ownership check
  return doc;
}
```

```typescript
// ERRADO — Confiar no ID da URL sem ownership check
async function getDocument(req: Request, docId: string) {
  return db.document.findUnique({ where: { id: docId } });
  // Qualquer usuário com ID válido acessa qualquer documento!
}
```

### A02: Cryptographic Failures

```typescript
// CERTO — Argon2id para senhas, AES-256-GCM para dados
import argon2 from "argon2";

const hash = await argon2.hash(password, {
  type: argon2.argon2id,
  memoryCost: 65536,     // 64 MB
  timeCost: 3,
  parallelism: 4,
});

// Verificação
const valid = await argon2.verify(hash, password);
```

```typescript
// ERRADO — MD5, SHA, bcrypt (deprecated para novos projetos)
import bcrypt from "bcrypt";
const hash = await bcrypt.hash(password, 10);
// bcrypt trunca em 72 bytes, tem vulnerabilidades conhecidas
```

### A03: Injection

```typescript
// CERTO — Parameterized queries (SQLx/Prisma)
// SQLx (Rust)
let users = sqlx::query_as!(User, "SELECT * FROM users WHERE tenant_id = $1", tenant_id)
    .fetch_all(&pool).await?;

// Prisma (TypeScript)
const users = await prisma.user.findMany({ where: { tenantId } });
```

```typescript
// ERRADO — Concatenação de SQL
const query = `SELECT * FROM users WHERE name = '${req.body.name}'`;
// SQL Injection: name = "'; DROP TABLE users; --"
```

### A04: Insecure Design (RLS Pattern)

```sql
-- CERTO — Row Level Security no PostgreSQL
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON documents
  USING (tenant_id = current_setting('app.tenant_id')::uuid);

-- Setar tenant no início de cada request
SET app.tenant_id = 'uuid-do-tenant';
```

### A05: Security Misconfiguration

```typescript
// CERTO — Headers de segurança
app.use((req, res, next) => {
  res.setHeader("X-Content-Type-Options", "nosniff");
  res.setHeader("X-Frame-Options", "DENY");
  res.setHeader("X-XSS-Protection", "0");  // Deprecated, mas safe
  res.setHeader("Strict-Transport-Security", "max-age=31536000; includeSubDomains");
  res.setHeader("Content-Security-Policy", "default-src 'self'; script-src 'self'");
  res.setHeader("Referrer-Policy", "strict-origin-when-cross-origin");
  res.setHeader("Permissions-Policy", "camera=(), microphone=(), geolocation=()");
  next();
});
```

```typescript
// ERRADO — Sem headers, CORS wildcard
app.use(cors({ origin: "*" }));  // Permite qualquer domínio
// Sem CSP, sem HSTS, sem X-Frame-Options
```

## 4. Checklist de Segurança Automatizado

### Frontend
- [ ] Sem dados sensíveis em localStorage/sessionStorage
- [ ] Cookies com HttpOnly, Secure, SameSite=Lax
- [ ] CSP header configurado
- [ ] Inputs sanitizados na renderização (React faz por padrão com JSX)
- [ ] Sem API keys/secrets no código client-side
- [ ] HTTPS enforced (redirect HTTP → HTTPS)
- [ ] `npm audit` sem vulnerabilidades high/critical

### Backend
- [ ] Inputs validados com schema (Zod/VineJS) em TODOS os endpoints
- [ ] Queries parametrizadas (nunca concatenação SQL)
- [ ] Senhas com Argon2id
- [ ] Rate limiting em login e endpoints sensíveis
- [ ] RBAC + ownership check em TODOS os endpoints de dados
- [ ] Audit log para mutações
- [ ] Soft delete em entidades core
- [ ] Lockout após 5 tentativas falhas
- [ ] Secrets em variáveis de ambiente (nunca no código)
- [ ] CORS com whitelist explícita de origens
- [ ] Campos sensíveis criptografados (AES-256-GCM)
- [ ] Headers de segurança configurados

### Infraestrutura
- [ ] TLS 1.2+ (preferencialmente 1.3)
- [ ] HSTS habilitado
- [ ] Database com RLS (Row Level Security)
- [ ] Backups criptografados
- [ ] Logs sem dados sensíveis (sem senhas, tokens, PII)
- [ ] Dependências atualizadas sem CVEs conhecidos

## 5. Ferramentas Automatizadas

| Ferramenta | Tipo | O que detecta |
|-----------|------|---------------|
| `npm audit` | SCA | Dependências vulneráveis |
| OWASP ZAP | DAST | Injection, XSS, misconfig |
| SonarQube | SAST | Code smells, security hotspots |
| Lighthouse | Audit | Best practices, HTTPS |
| `cargo audit` | SCA (Rust) | Crates vulneráveis |
| Trivy | Container | Vulnerabilidades em images Docker |

## 6. Zero-Trust

- **NUNCA** usar `any` em TypeScript para dados de input — usar `unknown` + type guard.
- **NUNCA** logar senhas, tokens, API keys ou dados pessoais.
- **NUNCA** usar MD5, SHA1 ou bcrypt para novas implementações de hash de senha.
- **NUNCA** confiar em validação client-side como única proteção.
- **NUNCA** usar CORS com `origin: "*"` em produção.
- **SEMPRE** usar HTTPS em produção.
- **SEMPRE** validar e sanitizar inputs no servidor.
- **SEMPRE** implementar rate limiting em endpoints de autenticação.
- **SEMPRE** usar prepared statements / parameterized queries.
