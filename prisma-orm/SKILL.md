---
name: Prisma ORM
description: Validate, generate, and optimize Prisma ORM schemas, migrations, and queries for Node.js/TypeScript. Enforces typed select, interactive transactions, safe raw queries, migration discipline, and seeding best practices.
---

# Prisma ORM — Diretrizes Sênior

## 1. Zero-Trust & Limites de Contexto

- **Antes de gerar qualquer schema**, externalize o modelo de dados em um artefato (`AI.md` ou `/brain/`).
- Faça **micro-commits**: edite um model/migration por vez, nunca reescreva o schema inteiro.
- Após concluir uma feature, **finalize a task** explicitamente para liberar contexto.
- Trate **todo input** que chega em queries como hostil — nunca interpolar strings em `$queryRaw`.
- **Nunca use `db push` em produção**. Sempre `migrate deploy`.

## 2. Estrutura de Projeto

```
prisma/
├── schema.prisma        # Schema principal
├── migrations/          # Migration files (versionadas no Git!)
├── seed.ts              # Seeding idempotente
└── schema/              # (opcional) Split schemas por domínio
    ├── user.prisma
    └── order.prisma

src/
├── lib/
│   └── prisma.ts        # Singleton do PrismaClient
└── ...
```

### Singleton do PrismaClient

```typescript
// ✅ CERTO — singleton com logging condicional
import { PrismaClient } from "@prisma/client";

const globalForPrisma = globalThis as unknown as { prisma: PrismaClient };

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    log:
      process.env.NODE_ENV === "development"
        ? ["query", "warn", "error"]
        : ["error"],
  });

if (process.env.NODE_ENV !== "production") globalForPrisma.prisma = prisma;

// ❌ ERRADO — instanciar em cada arquivo (connection pool esgota)
// import { PrismaClient } from '@prisma/client';
// const prisma = new PrismaClient(); // Nova instância por import!
```

## 3. Schema — Dogmas

### 3.1 Naming e Mapping

```prisma
// ✅ CERTO — camelCase no TS, snake_case no DB
model UserProfile {
  id        String   @id @default(cuid())
  userId    String   @map("user_id")
  firstName String   @map("first_name")
  createdAt DateTime @default(now()) @map("created_at")
  updatedAt DateTime @updatedAt @map("updated_at")

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@map("user_profiles")
}

// ❌ ERRADO — snake_case no TS (perde convenção do ecossistema)
model user_profile {
  id         String @id
  user_id    String
  first_name String
}
```

### 3.2 Soft Delete obrigatório em entidades core

```prisma
model Lead {
  id        String    @id @default(cuid())
  email     String
  deletedAt DateTime? @map("deleted_at")  // Soft delete

  @@index([email])
  @@index([deletedAt])    // Índice para filtrar ativos
  @@map("leads")
}
```

## 4. Queries — Dogmas

### 4.1 Sempre usar `select` explícito

```typescript
// ✅ CERTO — select explícito (retorna apenas o necessário)
const users = await prisma.user.findMany({
  where: { status: "active" },
  select: {
    id: true,
    name: true,
    email: true,
    _count: { select: { posts: true } },
  },
  take: 20,
  orderBy: { createdAt: "desc" },
});

// ❌ ERRADO — findMany sem select (retorna TODAS as colunas)
const users = await prisma.user.findMany({
  where: { status: "active" },
  // Inclui password_hash, tokens, etc!
});
```

### 4.2 Paginação cursor-based para listas grandes

```typescript
// ✅ CERTO — cursor pagination (performante em tabelas grandes)
const users = await prisma.user.findMany({
  take: 20,
  skip: 1, // Pular o cursor
  cursor: { id: lastSeenId }, // Cursor do último item
  orderBy: { id: "asc" },
  select: { id: true, name: true },
});

// ❌ ERRADO — offset pagination em tabelas com milhões de rows
const users = await prisma.user.findMany({
  skip: 100000, // Escaneia 100k rows para descartar!
  take: 20,
});
```

## 5. Transactions — Dogmas

```typescript
// ✅ CERTO — transaction interativa com rollback automático
const transfer = await prisma.$transaction(async (tx) => {
  const sender = await tx.account.update({
    where: { id: senderId },
    data: { balance: { decrement: amount } },
  });

  if (sender.balance < 0) {
    throw new Error("Saldo insuficiente"); // Rollback automático!
  }

  return tx.account.update({
    where: { id: receiverId },
    data: { balance: { increment: amount } },
  });
});

// ❌ ERRADO — operações sequenciais sem transaction
const sender = await prisma.account.update({
  where: { id: senderId },
  data: { balance: { decrement: amount } },
});
// Se crashar AQUI, dinheiro sumiu sem creditar!
const receiver = await prisma.account.update({
  where: { id: receiverId },
  data: { balance: { increment: amount } },
});
```

## 6. Raw Queries — SQL Injection Prevention

```typescript
// ✅ CERTO — template tag Prisma.sql (parameterizado)
const email = userInput;
const users = await prisma.$queryRaw`
  SELECT id, name FROM users WHERE email = ${email}
`;

// ❌ ERRADO — string interpolation (SQL INJECTION!)
const users = await prisma.$queryRawUnsafe(
  `SELECT * FROM users WHERE email = '${email}'`,
);
```

## 7. Migrations — Dogmas

| Ambiente  | Comando                     | Quando                          |
| --------- | --------------------------- | ------------------------------- |
| Dev       | `npx prisma migrate dev`    | Criar/aplicar migrations locais |
| CI/Test   | `npx prisma migrate deploy` | Aplicar migrations existentes   |
| Prod      | `npx prisma migrate deploy` | **Sempre deploy, NUNCA dev**    |
| Protótipo | `npx prisma db push`        | **Apenas** prototipação rápida  |

- Migrations são **versionadas no Git**. Nunca `.gitignore` a pasta `migrations/`.
- Nunca editar SQL de migrations já aplicadas em produção.
- Para dados de produção, criar migration separada com `-- Data Migration` no SQL.

## 8. Seeding — Idempotente

```typescript
// ✅ CERTO — upsert para idempotência
async function seed() {
  await prisma.role.upsert({
    where: { name: "admin" },
    update: {}, // Não sobrescrever se existir
    create: { name: "admin", permissions: ["*"] },
  });

  await prisma.role.upsert({
    where: { name: "user" },
    update: {},
    create: { name: "user", permissions: ["read"] },
  });
}

// ❌ ERRADO — create sem verificar (crash na segunda execução)
await prisma.role.create({ data: { name: "admin" } });
// Error: Unique constraint violation!
```

## 9. Performance

- **Connection pooling**: usar `connection_limit` em string de conexão (`?connection_limit=5`).
- Índices compostos com `@@index([field1, field2])` para queries frequentes.
- `relationLoadStrategy: 'join'` para evitar N+1 em includes.
- Usar `createMany` / `updateMany` para operações em lote.
- Monitorar slow queries com `log: ['query']` em dev.

## 10. Segurança

- Nunca expor `PrismaClient` diretamente nas rotas — sempre via Service/Repository.
- `DATABASE_URL` via `.env` (nunca hardcode).
- Usar `@db.VarChar(255)` para limitar tamanho de campos string.
- `onDelete: Cascade` explícito em relações (evitar orphans).
- Em multi-tenant: **SEMPRE** filtrar por `tenantId` como primeira cláusula `where`.
