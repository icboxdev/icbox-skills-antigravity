---
name: Senior Backend Engineering
description: Architect, secure, and optimize production-grade backend systems enforcing Clean Architecture, DDD boundaries, API design patterns, database optimization, authentication/authorization, observability, resiliency patterns, and deployment strategies. Covers Node.js/NestJS, but principles are framework-agnostic.
---

# Senior Backend Engineering — Diretrizes Sênior

## 1. Princípio Zero

Esta skill transforma o agente em um **Backend Architect** que entrega sistemas escaláveis, seguros e resilientes. Todo backend deve ser **testável**, **observável** e **deployável independentemente**.

Se o sistema funciona mas não escala, ele falhou. Se escala mas não é seguro, ele morreu.

## 2. Os 10 Pilares do Backend Sênior

| Pilar               | Descrição                                              | Métrica               |
| ------------------- | ------------------------------------------------------ | --------------------- |
| **Arquitetura**     | Clean Architecture, DDD, modular boundaries            | Acoplamento baixo     |
| **API Design**      | REST, GraphQL, gRPC — contracts first                  | Consistency score     |
| **Database**        | Schema design, indexing, query optimization            | Query time p95        |
| **Auth & Security** | OWASP, RBAC, OAuth 2.0, input validation               | 0 vulnerabilities     |
| **Scalability**     | Horizontal, caching, queues, event-driven              | Requests/s under load |
| **Resiliency**      | Circuit breaker, retry, bulkhead, graceful degradation | Uptime 99.9%+         |
| **Observability**   | Logs, metrics, traces, alerting                        | MTTD < 5min           |
| **Testing**         | Unit, integration, contract, load                      | Coverage > 80%        |
| **DevOps**          | CI/CD, containers, IaC, environments                   | Deploy time < 15min   |
| **Data Integrity**  | Transactions, migrations, validation, backups          | 0 data loss           |

## 3. Dogmas Inegociáveis

### Arquitetura — Clean Architecture + DDD

- SEMPRE organize em camadas: **Domain** → **Application** → **Infrastructure** → **Presentation**.
- SEMPRE defina **Bounded Contexts** — cada módulo/serviço tem sua fronteira clara.
- SEMPRE use **Dependency Inversion** — camadas internas nunca dependem das externas.
- SEMPRE separe: **Controllers** (thin) → **Services** (logic) → **Repositories** (data).
- SEMPRE use **DTOs** na fronteira de entrada/saída — nunca exponha entidades diretamente.
- NUNCA coloque lógica de negócio em controllers — eles apenas orquestram.
- NUNCA acesse o banco diretamente do controller — sempre via service → repository.
- NUNCA crie módulos com mais de 1 responsabilidade (SRP).

```
# CERTO: Clean Architecture / Domain-Driven modules
src/
├── modules/
│   ├── projects/
│   │   ├── dto/                    # Input/Output contracts
│   │   │   ├── create-project.dto.ts
│   │   │   └── project-response.dto.ts
│   │   ├── entities/               # Domain models
│   │   │   └── project.entity.ts
│   │   ├── services/               # Business logic
│   │   │   └── project.service.ts
│   │   ├── repositories/           # Data access abstraction
│   │   │   └── project.repository.ts
│   │   ├── controllers/            # HTTP handlers (thin)
│   │   │   └── project.controller.ts
│   │   └── project.module.ts
│   ├── auth/
│   ├── chat/
│   └── billing/
├── shared/
│   ├── guards/                     # Auth guards
│   ├── interceptors/               # Logging, transform
│   ├── filters/                    # Exception handlers
│   ├── decorators/                 # Custom decorators
│   └── types/                      # Shared types
├── config/                         # Environment config
└── main.ts

# ERRADO: Flat structure sem boundaries
src/
├── controllers/
│   ├── projectController.ts
│   ├── userController.ts          # 20+ controllers misturados
├── services/
├── models/
└── utils/
```

### API Design — Contract-First

- SEMPRE defina o contrato (DTO/Schema) **antes** da implementação.
- SEMPRE use **HTTP methods** corretos: GET (read), POST (create), PUT (replace), PATCH (update), DELETE (remove).
- SEMPRE use **status codes** significativos: 200, 201, 204, 400, 401, 403, 404, 409, 422, 429, 500.
- SEMPRE versione APIs: `/api/v1/projects` — nunca breaking changes sem versão nova.
- SEMPRE pagine listagens: `?page=1&limit=20` ou cursor-based `?cursor=xyz&limit=20`.
- SEMPRE retorne erros **consistentes**: `{ statusCode, message, error, details }`.
- NUNCA retorne toda a entidade do banco — selecione apenas campos necessários.
- NUNCA use verbos em URLs: `/api/getProjects` → `/api/v1/projects` (GET).

```typescript
// CERTO: DTO validado + resposta consistente
export class CreateProjectDto {
  @IsString()
  @MinLength(3)
  @MaxLength(100)
  name!: string;

  @IsString()
  @IsOptional()
  @MaxLength(500)
  description?: string;

  @IsEnum(ProjectType)
  type!: ProjectType;
}

// Response padronizado
interface ApiResponse<T> {
  data: T;
  meta?: {
    total: number;
    page: number;
    limit: number;
    hasMore: boolean;
  };
}

// Error response padronizado
interface ApiError {
  statusCode: number;
  message: string;
  error: string;
  details?: Record<string, string[]>;
  timestamp: string;
  path: string;
}

// ERRADO: Sem validação, retorna tudo
@Post()
async create(@Body() body: any) {          // ← any!
  return this.prisma.project.findFirst();  // ← entidade inteira!
}
```

### Database — Schema + Indexing + Queries

- SEMPRE defina **índices** para colunas usadas em WHERE, JOIN e ORDER BY.
- SEMPRE use **composite indexes** quando queremos filtrar por múltiplas colunas juntas.
- SEMPRE use `SELECT` apenas os campos necessários — nunca `SELECT *`.
- SEMPRE use **parametrized queries** — nunca concatene SQL com input do usuário.
- SEMPRE defina **foreign keys** e constraints para integridade referencial.
- SEMPRE use **transactions** para operações que envolvem múltiplas tabelas.
- SEMPRE use **migrations** versionadas — nunca altere schema manualmente em produção.
- NUNCA faça N+1 queries — use `include`/`join` ou data loader pattern.
- NUNCA armazene dados sensíveis sem hash (senhas) ou criptografia (PII).

```typescript
// CERTO: Query otimizada com select + index
const projects = await prisma.project.findMany({
  where: {
    ownerId: userId, // ← index: @@index([ownerId, status])
    status: "ACTIVE",
  },
  select: {
    id: true,
    name: true,
    status: true,
    createdAt: true,
    _count: { select: { modules: true } },
  },
  orderBy: { createdAt: "desc" },
  take: 20,
  skip: (page - 1) * 20,
});

// ERRADO: N+1 sem select
const projects = await prisma.project.findMany(); // todos os campos
for (const p of projects) {
  p.modules = await prisma.module.findMany({
    // N+1!
    where: { projectId: p.id },
  });
}
```

```prisma
// CERTO: Schema com índices
model Project {
  id        String   @id @default(uuid())
  name      String
  status    ProjectStatus @default(PENDING)
  ownerId   String
  owner     User     @relation(fields: [ownerId], references: [id])
  createdAt DateTime @default(now())

  @@index([ownerId, status])    // composite index
  @@index([status, createdAt])  // para listagens filtradas
}
```

### Auth & Security — OWASP Compliance

- SEMPRE use **HTTPS/TLS 1.3** — nunca HTTP em produção.
- SEMPRE valide **inputs no servidor** — class-validator, Zod, Joi. Client validation é UX, não segurança.
- SEMPRE use **parametrized queries** — previne SQL injection.
- SEMPRE hash senhas com **bcrypt** (cost ≥ 12) ou **argon2id**.
- SEMPRE armazene tokens em **httpOnly, Secure, SameSite cookies**.
- SEMPRE implemente **rate limiting** — por IP, por user, por endpoint.
- SEMPRE implemente **RBAC** — role-based access control centralizado.
- SEMPRE defina **CORS** restritivo — apenas origens conhecidas.
- SEMPRE sanitize outputs — previne XSS em APIs que retornam HTML.
- NUNCA exponha stack traces em produção — log interno, mensagem genérica pro client.
- NUNCA armazene secrets no código — use environment variables ou secret managers.
- NUNCA confie em dados do client — revalide TUDO server-side.

```typescript
// CERTO: Rate limiting por endpoint
@UseGuards(ThrottlerGuard)
@Throttle({ default: { limit: 5, ttl: 60000 } }) // 5 req/min
@Post('auth/login')
async login(@Body() dto: LoginDto) { ... }

// CERTO: RBAC Guard
@UseGuards(AuthGuard, RolesGuard)
@Roles('ADMIN', 'MANAGER')
@Delete(':id')
async deleteProject(@Param('id', ParseUUIDPipe) id: string) { ... }

// CERTO: Input validation
@Post()
async create(
  @Body(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true }))
  dto: CreateProjectDto,
) { ... }

// ERRADO: Sem validação, sem guard, sem rate limit
@Post()
async create(@Body() body: any) {
  return this.db.query(`INSERT INTO projects VALUES ('${body.name}')`); // SQL injection!
}
```

### Scalability — Horizontal + Event-Driven

- SEMPRE projete **stateless** — nenhum estado no processo. Session em Redis, files em S3.
- SEMPRE use **caching** em camadas: HTTP cache → CDN → Redis → DB.
- SEMPRE use **message queues** (Bull/BullMQ, RabbitMQ) para tasks assíncronas.
- SEMPRE use **connection pooling** no database.
- SEMPRE use **pagination** em todas as listagens — nunca retorne tudo.
- SEMPRE projete para **horizontal scaling** — múltiplas instâncias sem conflito.
- NUNCA faça operações longas (email, PDF, imagem) de forma síncrona — use filas.
- NUNCA armazene estado na memória do processo (sessions, uploads parciais).

```typescript
// CERTO: Task assíncrona via queue
@Injectable()
export class ProjectService {
  constructor(
    @InjectQueue('email') private emailQueue: Queue,
    private readonly prisma: PrismaService,
  ) {}

  async createProject(dto: CreateProjectDto, user: AuthUser) {
    const project = await this.prisma.project.create({ ... });

    // Async: não bloqueia a resposta
    await this.emailQueue.add('project-created', {
      userId: user.id,
      projectId: project.id,
    });

    return project;
  }
}

// ERRADO: Email síncrono bloqueando a resposta
async createProject(dto: CreateProjectDto) {
  const project = await this.prisma.project.create({ ... });
  await this.mailer.send(user.email, 'Projeto criado!'); // bloqueia 2-5s!
  return project;
}
```

### Resiliency — Fail Gracefully

- SEMPRE implemente **Circuit Breaker** para chamadas a serviços externos.
- SEMPRE tenha **retry com exponential backoff** para falhas transientes.
- SEMPRE defina **timeouts** em todas as chamadas externas (HTTP, DB, cache).
- SEMPRE tenha **health check** endpoint: `GET /health` → `{ status: 'ok', db: 'ok', redis: 'ok' }`.
- SEMPRE use **graceful shutdown** — espera requests pendentes antes de desligar.
- NUNCA deixe erros não tratados — global exception filter, catch boundaries.
- NUNCA tenha single point of failure sem fallback.

```typescript
// CERTO: Retry + Timeout + Circuit Breaker (conceitual)
async callExternalApi(endpoint: string): Promise<ExternalData> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 5000); // 5s timeout

  try {
    const response = await fetch(endpoint, {
      signal: controller.signal,
      headers: { 'Content-Type': 'application/json' },
    });

    if (!response.ok) {
      throw new HttpException('External service error', response.status);
    }

    return response.json() as Promise<ExternalData>;
  } catch (error: unknown) {
    if (error instanceof DOMException && error.name === 'AbortError') {
      throw new HttpException('External service timeout', 504);
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }
}
```

### Observability — Logs, Metrics, Traces

- SEMPRE use **structured logging** (JSON) — nunca `console.log` em produção.
- SEMPRE tenha **correlation ID** (request ID) em todos os logs de um request.
- SEMPRE monitore: request rate, error rate, latency (p50, p95, p99), DB pool.
- SEMPRE tenha **alertas** para: error rate > threshold, latência alta, disk/memory.
- SEMPRE log no nível correto: `error` (falha), `warn` (inesperado mas recuperável), `info` (eventos), `debug` (dev).
- NUNCA log dados sensíveis (senhas, tokens, PII).
- NUNCA use `console.log` — use logger estruturado (Pino, Winston).

```typescript
// CERTO: Structured logging com correlation ID
@Injectable()
export class LoggerMiddleware implements NestMiddleware {
  private readonly logger = new Logger("HTTP");

  use(req: Request, res: Response, next: NextFunction) {
    const requestId = req.headers["x-request-id"] || randomUUID();
    req["requestId"] = requestId;

    const start = Date.now();
    res.on("finish", () => {
      this.logger.log({
        requestId,
        method: req.method,
        url: req.url,
        status: res.statusCode,
        duration: `${Date.now() - start}ms`,
        userAgent: req.headers["user-agent"],
      });
    });

    next();
  }
}

// ERRADO: Console.log sem estrutura
console.log("Request received");
console.log(req.body); // pode logar senhas!
```

### Testing — Pirâmide Backend

```
        ┌──────────┐
        │  E2E/API │  ← Supertest (happy paths + error paths)
        │   ~10%   │    Tempo: lento
        ├──────────┤
        │  Integr. │  ← Service + DB real (test containers)
        │   ~30%   │    Tempo: médio
        ├──────────┤
        │   Unit   │  ← Services isolados (mocked deps)
        │   ~60%   │    Tempo: rápido
        └──────────┘
```

- SEMPRE teste **services** isoladamente com deps mockadas.
- SEMPRE teste **integração** com banco real (testcontainers ou test DB).
- SEMPRE teste **error paths** — não apenas happy paths.
- SEMPRE use **test factories** — nunca hardcode dados de teste.
- SEMPRE mocke **limites** (DB, HTTP, Queue), não módulos internos.
- NUNCA teste implementação privada — teste comportamento público.

```typescript
// CERTO: Service test com mock
describe("ProjectService", () => {
  it("should create project and enqueue email", async () => {
    // Arrange
    const mockPrisma = {
      project: { create: vi.fn().mockResolvedValue(fakeProject) },
    };
    const mockQueue = { add: vi.fn() };
    const service = new ProjectService(mockPrisma, mockQueue);

    // Act
    const result = await service.createProject(createProjectDto, fakeUser);

    // Assert
    expect(result.id).toBe(fakeProject.id);
    expect(mockQueue.add).toHaveBeenCalledWith("project-created", {
      userId: fakeUser.id,
      projectId: fakeProject.id,
    });
  });
});
```

### DevOps — CI/CD + Containers

- SEMPRE use **multi-stage Docker builds** — builder → runtime.
- SEMPRE rode como **non-root** no container.
- SEMPRE defina **healthcheck** no Dockerfile/docker-compose.
- SEMPRE tenha **CI pipeline**: lint → type-check → test → build → deploy.
- SEMPRE separe **environments**: dev → staging → production.
- ALWAYS use **env vars** para config — nunca hardcode URLs, secrets, ports.
- NUNCA exponha portas desnecessárias no container.
- NUNCA use `latest` tag em produção — sempre versione imagens.

## 4. Patterns de Referência

| Pattern              | Quando Usar                                     | Complexidade |
| -------------------- | ----------------------------------------------- | ------------ |
| **CRUD simples**     | Entidades sem lógica complexa                   | ⭐           |
| **Service Layer**    | Lógica de negócio entre controller e DB         | ⭐⭐         |
| **Repository**       | Abstração de acesso a dados                     | ⭐⭐         |
| **CQRS**             | Read/write models diferentes, alta performance  | ⭐⭐⭐       |
| **Event Sourcing**   | Audit trail, undo, event replay                 | ⭐⭐⭐⭐     |
| **Saga**             | Transações distribuídas entre serviços          | ⭐⭐⭐⭐     |
| **Circuit Breaker**  | Chamadas a serviços externos                    | ⭐⭐         |
| **BFF**              | Frontend-specific API aggregation               | ⭐⭐         |
| **Modular Monolith** | Bounded contexts sem overhead de micro-services | ⭐⭐⭐       |

## 5. Checklist de Code Review Backend

- [ ] **Arquitetura** — Clean layers, DDD boundaries, thin controllers, SRP
- [ ] **API** — RESTful, status codes corretos, DTOs validados, paginação
- [ ] **Database** — Índices, select fields, N+1 resolvido, migrations, transactions
- [ ] **Security** — Input validation server-side, RBAC, rate limiting, no secrets no code
- [ ] **Auth** — httpOnly cookies, CORS restritivo, hash bcrypt/argon2id
- [ ] **Scalability** — Stateless, caching, queues para async, connection pooling
- [ ] **Resiliency** — Timeouts, retries, circuit breakers, health checks
- [ ] **Observability** — Structured logs, no PII logged, correlation ID, alertas
- [ ] **Testing** — Services testados, integration com DB, error paths, factories
- [ ] **DevOps** — Multi-stage Docker, non-root, CI green, env vars

## 6. Ferramentas Essenciais (2025)

| Categoria      | Ferramenta               | Alternativa            |
| -------------- | ------------------------ | ---------------------- |
| **Runtime**    | Node.js 22 LTS           | Bun, Deno              |
| **Framework**  | NestJS                   | Fastify, Hono, Express |
| **ORM**        | Prisma                   | Drizzle, TypeORM, Knex |
| **Validation** | class-validator / Zod    | Joi, Yup               |
| **Auth**       | Supabase Auth / Passport | Auth.js, Lucia         |
| **Cache**      | Redis (Upstash)          | Memcached, KeyDB       |
| **Queue**      | BullMQ                   | RabbitMQ, SQS          |
| **Testing**    | Vitest + Supertest       | Jest, Mocha            |
| **Logging**    | Pino                     | Winston, Bunyan        |
| **Monitoring** | Sentry + Prometheus      | Datadog, New Relic     |
| **Container**  | Docker + Compose         | Podman                 |
| **CI/CD**      | GitHub Actions           | GitLab CI, Coolify     |
| **Database**   | PostgreSQL (Supabase)    | MySQL, CockroachDB     |
