---
name: Node.js (NestJS / Fastify) Strict
description: Validate, architect, and generate Node.js APIs ensuring structural DI (Dependency Injection), strict typing without \`any\`, thin controllers, standardized repositories, and centralized error handling.
---

# Node.js Backend Strict — Diretrizes Sênior

## 1. Princípio Zero: Zero-Trust e Context Limits

- **Arquivos Primeiros**: Antes de iniciar grandes listagens ou modelar BD, crie um arquivo `ARCHITECTURE.md` no workspace detalhando o Service e o Repository. Externalize a memória.
- **Sanitização Universal**: Presuma que a request originada do frontend tenta uma injeção ou falha de tipo. A validação do DTO é obrigatória.
- **Micro-commits**: Termine cada modificação/geração lógicamente fechada. Não crie Service, Controller, Repository e Module no mesmo prompt. Vá passo a passo.

## 2. Arquitetura SOLID e Tipagem

### Princípios Obrigatórios

- **SRP (Single Responsibility)**: Controllers lidam com HTTP. Services processam regras de negócio. Repositories acessam dados.
- **`any` é proibido**: Proibido usar `any` em todo o repositório. Use `unknown` com guard expressions.

### Few-Shot: DTO e Reposta

**Sempre valide inputs via Pipe/Schema. Nunca confie no objeto brut.**

```typescript
// CERTO (Com Validador e Tipagem Estrita)
export class CreateUserDto {
  @IsEmail()
  @IsNotEmpty()
  email: string;

  @IsString()
  @MinLength(8)
  password: string;
}

@Post()
async create(@Body(ValidationPipe) dto: CreateUserDto): Promise<UserResponse> {
  return this.usersService.create(dto);
}

// ERRADO (Inferência solta, confiando no body)
@Post()
async create(@Body() body: any) {
  return this.usersService.create(body.email, body.password);
}
```

## 3. Injeção de Dependências (DI)

### Few-Shot: Injeção por Construtor (NestJS)

- Nunca instancie classes "na mão" (Ex: `new PrismaService()`).
- O framework resolve as dependências via Inversão de Controle no construtor.

```typescript
// CERTO
@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async findUser(id: string): Promise<User> {
    return this.prisma.user.findUniqueOrThrow({ where: { id } });
  }
}

// ERRADO
export class UsersService {
  private prisma = new PrismaService(); // Violação de DIP
}
```

## 4. Error Handling Centralizado

- Nunca vaze Stack Trace.
- Capture em filtros de Exceção Global (Nest) ou hook (`setErrorHandler` no Fastify).

### Few-Shot: Tratamento de Exceções

```typescript
// CERTO (Instanciando Exceções Tipadas do Framerwork)
if (!user) {
  throw new NotFoundException("Usuário não localizado no sistema.");
}

// ERRADO
if (!user) {
  throw new Error("Usuário null"); // Retornará 500 no HTTP.
}
```

## 5. Performance Node.js

- **Event Loop Bloqueado**: Jamais use funções síncronas do `fs` (`fs.readFileSync`) em controllers ou serviços quentes. Force o uso de `fs/promises`.
- Cache: Se consultar a mesma tabela de configurações em todo request, proponha a injeção do gerenciador de Cache (`Redis` ou In-memory).

## Resumo do Escopo

Você só atua quando orquestrando, debugando ou gerando Node.js. Pare sua tarefa e peça aprovação após fechar a construção arquitetural (Module, Controller, Service).
