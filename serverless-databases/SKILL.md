---
name: Serverless Databases & Edge Data
description: Architect, validate, and optimize serverless databases (Neon, PlanetScale, Turso, DynamoDB) enforcing connection pooling at the edge, cold-start mitigation, and database branching CI/CD workflows.
---

# Serverless Databases & Edge Data

O paradigma Serverless para banco de dados exige repensar o ciclo de vida das conexões, o provisionamento de recursos e os fluxos de migração (Branching). Siga estas diretrizes rigorosamente para garantir escalabilidade infinita sem esgotar conexões ou custos.

## 🏛️ Dogmas de Arquitetura Serverless DB

1. **PROIBA a criação de conexões sem Pooling Global:** Em ambientes serverless (Vercel, AWS Lambda), as funções nascem e morrem rapidamente. Conexões diretas ao DB esgotam o limite instantaneamente. OBRIGATÓRIO o uso de Connection Poolers no Edge (ex: AWS RDS Proxy, Prisma Accelerate, Neon Pooler).
2. **APLIQUE Database Branching no CI/CD:** Bancos modernos (Neon, PlanetScale, Turso) suportam "Git-like branching". NUNCA rode migrations direto em produção. Crie uma branch do banco (`main` -> `feature-x`), aplique as migrations, teste e faça o deploy (Swap/Deploy Request).
3. **MITIGUE Cold Starts Estrategicamente:** Bancos Serverless que escalam para zero (Scale-to-Zero) sofrem de Cold Start. Se a aplicação é sensível à latência no first-byte, MANTENHA um compute mínimo "Warm" ou utilize Serverless Drivers (HTTP/WebSocket ao invés de TCP).
4. **USE Edge Replicas (Turso/libSQL):** Para aplicações globais onde latência é crítica (\< 10ms), utilize Turso (SQLite no Edge) para replicar o banco em dezenas de regiões mais próximas aos usuários, direcionando as ESCRITAS para a master e LEITURAS para o edge local.
5. **DYNAMODB: Design de Tabela Única (Single-Table Design):** Se usar DynamoDB, ESMAGUE os dados relacionais em uma única tabela usando Primary Keys (PK) e Sort Keys (SK) compostas. NUNCA faça "Joins" a nível de aplicação em NoSQL serverless de alta performance.

## 🛑 Padrões (Certo vs Errado)

### Connection Pooling (Neon / Vercel Edge)

**❌ ERRADO** (Criação de client TCP direto no Edge, esgota as conexões do PostgreSQL rapidamento):
```typescript
import { Client } from 'pg';

export async function GET() {
  // CRÍTICO: Cria uma nova conexão TCP a cada invocation serverless!
  const client = new Client(process.env.DATABASE_URL); 
  await client.connect();
  const res = await client.query('SELECT * FROM users');
  await client.end();
  return Response.json(res.rows);
}
```

**✅ CERTO** (Utilizando Driver Serverless via HTTP/WebSocket projetado para escalar a zero sem estourar limites):
```typescript
// Usa o driver oficial do Neon que gerencia pooling via WebSocket/HTTP
import { neon } from '@neondatabase/serverless';

export async function GET() {
  // Conexão via HTTP/WS. Não esgota o limit de TCP do PG e suporta edge.
  const sql = neon(process.env.DATABASE_URL);
  const rows = await sql`SELECT * FROM users`;
  
  return Response.json(rows);
}
```

### Turso (SQLite Edge Replication)

**❌ ERRADO** (Escrever no SQLite em um container transiente ou serverless):
```javascript
// O arquivo SQLite será APAGADO quando a função serverless desligar.
const db = new sqlite3.Database('/tmp/mydb.sqlite');
db.run("INSERT INTO hits VALUES (1)"); 
```

**✅ CERTO** (Client do LibSQL sincronizando com o Turso na nuvem):
```typescript
import { createClient } from "@libsql/client";

// O client escreve na master do Turso via HTTPS e lê da réplica no edge
const client = createClient({
  url: process.env.TURSO_DATABASE_URL,
  authToken: process.env.TURSO_AUTH_TOKEN,
});

const result = await client.execute("SELECT * FROM users WHERE active = 1");
```

## 🔄 Fluxo de Deploy com Branching (PlanetScale / Neon)

Ao invés de rodar `npx prisma migrate deploy` contra o DB de produção:

1. **Crie a Branch**: `pscale branch create my-db feat-user-profile`
2. **Conecte o App Local**: Conecte na branch `feat-user-profile`.
3. **Aplique Migrations na Branch**: Altere o schema, rode `npx prisma db push` contra a branch.
4. **Deploy Request**: Abra um Pscale Deploy Request ou realize o schema diff no Neon. O provedor fará o merge do schema com ZERO downtime.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

