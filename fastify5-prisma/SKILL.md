---
name: Fastify 5 & Prisma 6 Microservices
description: Architect, generate, and validate Fastify 5 microservices with Prisma 6, ESM TypeScript, Zod validation, BullMQ workers, and centralized error handling. Enforces plugin architecture, timing-safe M2M auth, and strict TypeScript patterns.
---

# Fastify 5 + Prisma 6 — Diretrizes Sênior

## 1. Princípio Zero: Fastify ≠ NestJS

Fastify é um framework **plugin-based** sem decorators mágicos. Não confundir padrões NestJS (`@Injectable`, `@Controller`) com Fastify.

- **Plugins são a unidade de composição**: Todo módulo registra via `fastify.register()`.
- **Sem DI framework**: DI é manual via `fastify.decorate()` ou closure.
- **ESM obrigatório**: `"type": "module"` no `package.json`. Imports DEVEM ter `.js` extension.
- **Zod > class-validator**: Validação via Zod schemas, não decorators.
- **Micro-commits**: Um plugin, um módulo por vez. Não construa tudo num prompt.

## 2. Stack Obrigatória

```json
{
  "runtime": "Node.js 22+ (Debian Slim)",
  "module": "ESM (\"type\": \"module\")",
  "framework": "Fastify 5",
  "orm": "Prisma 6",
  "validation": "Zod",
  "jobs": "BullMQ + Redis",
  "docs": "@fastify/swagger + @scalar/fastify-api-reference"
}
```

## 3. Estrutura de Projeto

```
src/
├── app.ts               # Fastify instance + plugin registration
├── server.ts            # Listen + graceful shutdown
├── config/
│   └── env.ts           # Zod environment validation (fail-fast)
├── lib/
│   ├── prisma.ts        # PrismaClient singleton
│   ├── redis.ts         # Redis connection + URL parser
│   └── queue.ts         # BullMQ queue factory
├── plugins/
│   ├── auth.ts          # Master Key / JWT auth (fp())
│   ├── error-handler.ts # Global error handler (fp())
│   └── docs.ts          # Swagger + Scalar UI (fp())
├── modules/
│   └── <domain>/
│       ├── routes.ts    # Route definitions
│       ├── service.ts   # Business logic
│       └── schema.ts    # Zod schemas (request/response)
└── jobs/
    ├── worker.ts        # BullMQ worker bootstrap
    └── handlers/        # Job handler functions
```

## 4. ESM Imports — Regra Crítica

```typescript
// CERTO: extensão .js OBRIGATÓRIA (mesmo importando .ts)
import { env } from "./config/env.js";
import { prisma } from "./lib/prisma.js";
import authPlugin from "./plugins/auth.js";

// ERRADO: sem extensão (falha em runtime com NodeNext)
import { env } from "./config/env";
import { prisma } from "./lib/prisma";
```

## 5. Environment Validation (Fail-Fast)

```typescript
// src/config/env.ts
import { z } from "zod";

const envSchema = z.object({
  DATABASE_URL: z.string().url(),
  REDIS_URL: z.string().default("redis://localhost:6379"),
  MASTER_KEY: z.string().min(32),
  PORT: z.coerce.number().default(3001),
  NODE_ENV: z.enum(["development", "production"]).default("development"),
});

export const env = envSchema.parse(process.env);
export type Env = z.infer<typeof envSchema>;

// ERRADO: process.env.PORT sem validação (pode ser undefined)
```

## 6. Plugin Architecture

### Regras de Plugins

- Use `fastify-plugin` (`fp()`) para plugins que compartilham estado (auth, error-handler).
- **NÃO** use `fp()` para módulos de rotas — preservar encapsulamento.
- Registre plugins ANTES de rotas no `app.ts`.

```typescript
// CERTO: Plugin com fp() para decorators compartilhados
import fp from "fastify-plugin";
import type { FastifyInstance } from "fastify";

export default fp(async (fastify: FastifyInstance) => {
  fastify.decorate("authenticate", async (request, reply) => {
    const key = request.headers["x-master-key"];
    if (!key || !safeCompare(key, env.MASTER_KEY)) {
      reply.code(401).send({ error: { code: "UNAUTHORIZED", message: "Invalid key" } });
    }
  });
});

// ERRADO: Plugin sem fp() — decorators ficam encapsulados e invisíveis
```

## 7. Empty Body Parser (Gotcha Fastify 5)

Fastify 5 lança `FST_ERR_CTP_EMPTY_JSON_BODY` se `Content-Type: application/json` vier sem body.

```typescript
// CERTO: Registrar no app.ts ANTES de qualquer rota
app.addContentTypeParser(
  "application/json",
  { parseAs: "string" },
  (_req, body, done) => {
    try {
      const str = (body as string).trim();
      done(null, str ? JSON.parse(str) : {});
    } catch (err) {
      done(err as Error, undefined);
    }
  },
);

// ERRADO: Não tratar — frontend faz POST sem body e recebe 500
```

## 8. Error Handler Centralizado

```typescript
// src/plugins/error-handler.ts
import fp from "fastify-plugin";
import { ZodError } from "zod";
import { Prisma } from "@prisma/client";

export default fp(async (fastify) => {
  fastify.setErrorHandler((error, request, reply) => {
    // Zod validation errors → 400
    if (error instanceof ZodError) {
      return reply.code(400).send({
        error: {
          code: "VALIDATION_ERROR",
          message: "Invalid input",
          details: error.flatten().fieldErrors,
        },
      });
    }

    // Prisma not found → 404
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2025") {
      return reply.code(404).send({
        error: { code: "NOT_FOUND", message: "Resource not found" },
      });
    }

    // Rate limit → 429
    if (error.statusCode === 429) {
      return reply.code(429).send({
        error: { code: "RATE_LIMITED", message: "Too many requests" },
      });
    }

    // Tudo mais → 500 (mascarado em produção)
    request.log.error(error);
    reply.code(500).send({
      error: {
        code: "INTERNAL_ERROR",
        message: process.env.NODE_ENV === "production" ? "Internal error" : error.message,
      },
    });
  });
});
```

## 9. Timing-Safe Master Key Auth (M2M)

```typescript
import { timingSafeEqual } from "node:crypto";

function safeCompare(input: string, expected: string): boolean {
  const inputBuf = Buffer.from(input);
  const expectedBuf = Buffer.from(expected);

  // Padding constante: se lengths diferem, compara expected consigo mesmo
  if (inputBuf.length !== expectedBuf.length) {
    timingSafeEqual(expectedBuf, expectedBuf);
    return false;
  }

  return timingSafeEqual(inputBuf, expectedBuf);
}

// ERRADO: input === expected (timing attack!)
// ERRADO: early return no length check sem dummy comparison
```

## 10. Prisma 6 Patterns

### JSON Field Casting

```typescript
// CERTO: Sempre cast para Prisma.InputJsonValue
await prisma.gateway.update({
  where: { id },
  data: {
    config: validatedConfig as unknown as Prisma.InputJsonValue,
    metadata: Prisma.JsonNull, // Limpar campo JSON
  },
});

// ERRADO: Passar Record<string, unknown> direto (type error)
```

### Prisma 6 vs 7 Coexistência

```bash
# CERTO: Usar CLI local quando main API usa Prisma 7
cd backend/microservice
./node_modules/.bin/prisma generate

# ERRADO: npx prisma generate (pode puxar v7 global)
```

### Evitar N+1 com groupBy

```typescript
// CERTO: Uma query com groupBy + Map para lookup O(1)
const groups = await prisma.gateway.groupBy({
  by: ["tenantSlug"],
  _count: { id: true },
});
const countMap = new Map(groups.map((g) => [g.tenantSlug, g._count.id]));

// ERRADO: tenants.map(t => prisma.gateway.count({ where: { tenantSlug: t.slug } }))
```

## 11. BullMQ Patterns

### Scheduling (upsertJobScheduler)

```typescript
// CERTO: Idempotente — seguro para chamar no boot
await queue.upsertJobScheduler(
  "health-check-scheduler",
  { every: 60 * 60 * 1000 }, // 1h
  { name: "health-check", data: { scope: "__all__" } },
);
```

### Redis URL Parsing

```typescript
// CERTO: Parsear REDIS_URL para BullMQ connection options
function getRedisConnection() {
  const parsed = new URL(process.env.REDIS_URL ?? "redis://localhost:6379");
  return {
    host: parsed.hostname || "localhost",
    port: Number(parsed.port) || 6379,
    password: parsed.password || undefined,
    maxRetriesPerRequest: null, // Obrigatório para BullMQ
  };
}
```

## 12. Graceful Shutdown

```typescript
// src/server.ts
const signals: NodeJS.Signals[] = ["SIGINT", "SIGTERM"];

for (const signal of signals) {
  process.on(signal, async () => {
    fastify.log.info(`Received ${signal}, shutting down...`);
    await worker?.close();    // BullMQ worker primeiro
    await fastify.close();    // Fastify server segundo
    await prisma.$disconnect(); // Prisma por último
    process.exit(0);
  });
}
```

## 13. Fastify 5 TypeScript Gotchas

| Problema | Solução |
|---|---|
| `FastifyInstance` requer 5 type args | Use `any` para args não especializados em plugins |
| `reply.status()` tem generics complexos | Use **`reply.code()`** (mais limpo) |
| `FastifyError` import falha | Importar de `@fastify/error` |
| Empty `declare module "fastify"` quebra tipos | Remover augmentação vazia ou usar `export {}` |
| `as const` em schemas JSON | Obrigatório para `type: "object" as const` |

## 14. Constraints — O que NUNCA Fazer

- ❌ NUNCA importe sem `.js` extension em ESM
- ❌ NUNCA use `npx prisma generate` quando coexistindo com Prisma 7
- ❌ NUNCA use `reply.status()` — use `reply.code()`
- ❌ NUNCA confie em `Content-Type: application/json` ter body (registre parser)
- ❌ NUNCA use `=== ` para comparar Master Keys (timing attack)
- ❌ NUNCA use `(err as any).statusCode` — use type guards
- ❌ NUNCA use class-validator/class-transformer — use Zod
- ❌ NUNCA registre rotas ANTES de plugins globais
- ❌ NUNCA use `as Record<string, unknown>` para campos Prisma JSON — use Zod parse

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.
