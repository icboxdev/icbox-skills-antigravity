---
name: AdonisJS Backend & PostgreSQL Scale
description: Architect, generate, and validate AdonisJS backends with PostgreSQL for high-scale environments. Enforces repository pattern, structural DI, zero-trust validation (VineJS), strict Lucid ORM performance boundaries, and multi-tenant security.
---

# AdonisJS & PostgreSQL — Diretrizes de Alta Escala Sênior

## 1. Zero-Trust & Limites de Contexto

- **O input é sempre malicioso**: Toda e qualquer entrada de dados (body, params, querystring) DEVE ser validada usando **VineJS**.
- **Regra de Borda**: Controladores (`Controllers`) são magros. Eles apenas recebem requests, chamam o `Validator`, passam para o `Service` e retornam a resposta. NUNCA coloque regras de negócio complexas no Controller.
- **Tipagem Estrita**: NUNCA use `any`. Use retornos explícitos em métodos de Services e Controllers.
- **Micro-commits**: Uma feature por vez (Controller + Service + Repository + Tests).

## 2. Padrão Arquitetural: Service/Repository Baseado em DI

Use a Injeção de Dependências (DI) nativa do AdonisJS v6 para separar responsabilidades e garantir testabilidade.

### Camadas Obrigatórias

1. **Controllers**: Tratam HTTP (Request/Response) e validação.
2. **Services**: Contêm a lógica de negócio pura, isolada do HTTP.
3. **Repositories**: (Opcional, mas recomendado para alta escala) Isolam as queries do Lucid ORM.

### 2.1 Padrão DI (Injeção via Construtor)

```typescript
// ✅ CERTO — Injeção de Dependência pelo construtor (Testável)
import { inject } from "@adonisjs/core";
import { UserService } from "#services/user_service";
import type { HttpContext } from "@adonisjs/core/http";

@inject()
export default class UsersController {
  constructor(private userService: UserService) {}

  async store({ request, response }: HttpContext) {
    const payload = await request.validateUsing(createUserValidator);
    const user = await this.userService.create(payload);
    return response.created(user);
  }
}

// ❌ ERRADO — Instanciação manual ou lógica no controller
export default class UsersController {
  async store({ request, response }: HttpContext) {
    const payload = request.all(); // ❌ Sem validação!
    const user = new User();
    user.fill(payload);
    await user.save(); // ❌ Business logic no controller!
    return response.created(user);
  }
}
```

## 3. Validação Blindada (VineJS Dogmas)

VineJS é a única fonte de verdade para a forma dos dados.

```typescript
// ✅ CERTO — Validator rígido com trim e escape
import vine from '@vinejs/vine'

export const createUserValidator = vine.compile(
  vine.object({
    email: vine.string().email().normalizeEmail(),
    password: vine.string().minLength(8).maxLength(32),
    name: vine.string().trim().escape().minLength(2),
  })
)

// O Tipo é inferido automaticamente:
export type CreateUserPayload = await vine.infer<typeof createUserValidator>
```

## 4. Lucid ORM & PostgreSQL — Alta Escala

Bancos de dados de larga escala caem por N+1, travas de transação e scans integrais.

### 4.1 Selects Explícitos Sempre

Nunca puxe todas as colunas de tabelas gigantes se não for usá-las.

```typescript
// ✅ CERTO — Selects explícitos e paginação
const users = await User.query()
  .select("id", "name", "email")
  .where("status", "active")
  .orderBy("created_at", "desc")
  .paginate(page, 20);

// ❌ ERRADO — Select * em tabela de produção e uso de offset solto
const users = await User.query().where("status", "active");
```

### 4.2 Cuidado com N+1 (Preloading)

```typescript
// ✅ CERTO — Eager loading com colunas específicas
const posts = await Post.query()
  .preload("author", (q) => q.select("id", "name"))
  .paginate(1, 10);

// ❌ ERRADO — N+1 na view/service
const posts = await Post.all();
for (const post of posts) {
  await post.load("author"); // Dispara 1 query para cada post!
}
```

### 4.3 Transações Seguras

Transações devem ser curtas para não prender a connection pool.

```typescript
// ✅ CERTO — Transações gerenciadas pelo Adonis
import db from "@adonisjs/lucid/services/db";

await db.transaction(async (trx) => {
  const order = new Order();
  order.total = 100;
  order.useTransaction(trx);
  await order.save();

  await Payment.create({ orderId: order.id, amount: 100 }, { client: trx });
});
// Commit ou rollback automáticos

// ❌ ERRADO — Deixar a transação solta e esquecer o rollback no try/catch
const trx = await db.transaction();
await Order.create(data, { client: trx });
// Se jogar um erro no meio, o .commit() nunca é chamado e a conexão vaza!
```

## 5. Multi-Tenant Safeties (Row-Level / App-Level)

Se a aplicação for multi-tenant, proteja as queries globalmente para evitar vazamento cruzado.

- **Dogma**: Toda entidade relacionada a um cliente deve exigir o `tenantId`.
- Crie um `BaseModel` customizado (ou use global scopes) para injetar o tenant.

```typescript
// ✅ CERTO — Forçando o isolamento explícito
export default class ProjectService {
  async findById(tenantId: string, projectId: string) {
    const project = await Project.query()
      .where("tenant_id", tenantId) // Garantia atômica
      .where("id", projectId)
      .firstOrFail();
    return project;
  }
}
```

## 6. Connection Pooling & DB Tunning (PostgreSQL)

O AdonisJS usa o Knex por baixo. No arquivo `config/database.ts`:

- Ajuste a `pool` de acordo com a RAM e os cores do banco:
  ```typescript
  pool: {
    min: 2,
    max: process.env.DB_POOL_MAX ? parseInt(process.env.DB_POOL_MAX) : 10,
    idleTimeoutMillis: 30000,
  }
  ```
- Use conexões PgBouncer via `pgBouncer: true` se estiver rodando serverless ou muitos microserviços.

## 7. Segurança

- A API DEVE ter **CORS** restrito a origens conhecidas (`config/cors.ts`).
- Em APIs abertas, o pacote `@adonisjs/limiter` (Rate Limiting) é OBRIGATÓRIO (ex: 50 reqs/min).
- Senhas NUNCA trafegam nos logs escolares, garanta que propriedades do Lucid como `password` estejam sinalizadas como nulas ou excluídas na serialização (`@column({ serializeAs: null })`).
- Utilize **Adonis Bouncer** para RBAC/ABAC seguro, nunca resolva permissões em `if` espalhados pelo código.

## 8. Anti-Patterns a não cometer

- ❌ `request.all()` sem passar pelo Validator.
- ❌ `.save()` dentro de loop (use `createMany` ou transactions).
- ❌ Controllers gordinhos com mais de 100 linhas (mova para Service).
- ❌ Logar o objeto de Request completo (vaza PII e tokens). Use o `@adonisjs/logger` (Pino) com serialização segura.
