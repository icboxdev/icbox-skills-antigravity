---
name: TypeScript Advanced Patterns
description: Validate, enforce, and generate advanced TypeScript patterns including branded types, type guards, discriminated unions, utility types, const assertions, and satisfies operator. Prevents type unsafety across all TypeScript stacks.
---

# TypeScript — Padrões Avançados Sênior

## 1. Zero-Trust & Limites de Contexto

- **`any` é terminantemente proibido**. Sem exceção. Use `unknown` + type guard.
- **`as` type assertion** é proibido exceto em testes. Prefira `satisfies` ou guards.
- Faça **micro-commits**: tipar um módulo por vez.
- `strict: true` no `tsconfig.json` é inegociável.

## 2. Branded Types — IDs Seguros

```typescript
// ✅ CERTO — IDs tipados que não se misturam
type Brand<T, B extends string> = T & { readonly __brand: B };

type UserId = Brand<string, "UserId">;
type OrderId = Brand<string, "OrderId">;

function createUserId(id: string): UserId {
  return id as UserId; // Cast controlado na factory
}

function getUser(id: UserId) {
  /* ... */
}
function getOrder(id: OrderId) {
  /* ... */
}

const userId = createUserId("abc-123");
getUser(userId); // ✅ OK
// getOrder(userId); // ❌ TS Error — UserId ≠ OrderId

// ❌ ERRADO — IDs intercambiáveis (bugs silenciosos)
function getUser(id: string) {
  /* ... */
}
function getOrder(id: string) {
  /* ... */
}
getOrder(userId); // Compila sem erro mas é um BUG!
```

## 3. Type Guards — Narrowing Seguro

```typescript
// ✅ CERTO — type guard com `is`
interface ApiError {
  code: string;
  message: string;
}

function isApiError(value: unknown): value is ApiError {
  return (
    typeof value === "object" &&
    value !== null &&
    "code" in value &&
    "message" in value &&
    typeof (value as ApiError).code === "string"
  );
}

// Uso seguro:
const response: unknown = await fetchApi();
if (isApiError(response)) {
  console.error(response.code); // TS sabe que é ApiError
}

// ❌ ERRADO — type assertion cega
const response = (await fetchApi()) as ApiError; // E se não for?
console.error(response.code); // Runtime crash se formato diferente!
```

## 4. `satisfies` — Validar Sem Alargar

```typescript
// ✅ CERTO — satisfies preserva literal types
const config = {
  api: "https://api.example.com",
  timeout: 5000,
  retries: 3,
} satisfies Record<string, string | number>;

// config.api é inferido como string (literal 'https://...')
// config.timeout é number
// config.retries é number

// ❌ ERRADO — `as const` sem validação de shape
const config = {
  api: "https://api.example.com",
  timeout: 5000,
  retriess: 3, // Typo! Ninguém percebe
} as const;
```

## 5. Discriminated Unions — Exaustividade

```typescript
// ✅ CERTO — union discriminada com exaustive check
type Result<T> =
  | { status: "success"; data: T }
  | { status: "error"; error: string }
  | { status: "loading" };

function handleResult(result: Result<User>) {
  switch (result.status) {
    case "success":
      return renderUser(result.data);
    case "error":
      return showError(result.error);
    case "loading":
      return showSpinner();
    default:
      const _exhaustive: never = result; // TS Error se faltar case
      return _exhaustive;
  }
}

// ❌ ERRADO — union com string literal sem exhaustive check
function handleResult(result: { status: string; data?: any }) {
  if (result.status === "success") return result.data;
  // 'loading' e 'error' ignorados silenciosamente
}
```

## 6. Utility Types Avançados

```typescript
// ✅ CERTO — Utility types para queries parciais
type CreateDTO<T> = Omit<T, "id" | "createdAt" | "updatedAt">;
type UpdateDTO<T> = Partial<CreateDTO<T>>;

interface User {
  id: string;
  name: string;
  email: string;
  createdAt: Date;
  updatedAt: Date;
}

type CreateUserDTO = CreateDTO<User>;
// = { name: string; email: string }

type UpdateUserDTO = UpdateDTO<User>;
// = { name?: string; email?: string }

// ❌ ERRADO — duplicar interfaces para cada operação
interface CreateUserDTO {
  name: string;
  email: string;
}
interface UpdateUserDTO {
  name?: string;
  email?: string;
}
// Duplicação! Se User mudar, DTOs ficam dessincronizados
```

## 7. Template Literal Types

```typescript
// ✅ CERTO — rotas tipadas com template literal
type ApiRoute = `/api/v1/${string}`;
type EventName = `on${Capitalize<string>}`;

function navigate(route: ApiRoute) {
  /* ... */
}
navigate("/api/v1/users"); // ✅
// navigate('/users');        // ❌ TS Error

// Tipagem automática de chaves de tradução
type Locale = "en" | "pt";
type Namespace = "common" | "auth";
type I18nKey = `${Namespace}.${string}`;

function t(key: I18nKey, locale: Locale): string {
  /* ... */
}
t("auth.login_success", "pt"); // ✅
// t('invalid', 'pt');          // ❌ Não começa com namespace
```

## 8. `Record<string, never>` vs `{}`

```typescript
// ✅ CERTO — tipo vazio explícito
type EmptyObject = Record<string, never>;

function process(config: EmptyObject) {
  /* ... */
}
process({}); // ✅
// process({ key: 'value' });  // ❌ TS Error

// ❌ ERRADO — {} aceita QUALQUER objeto (até string e number)
function process(config: {}) {
  /* ... */
}
process("string"); // ✅ Compila! {} aceita tudo exceto null/undefined
process(42); // ✅ Compila!
```

## 9. Anti-Patterns

- ❌ `any` — usar `unknown` + guard
- ❌ `as` para silenciar erros — usar `satisfies` ou narrowing
- ❌ `!` (non-null assertion) sem verificação — checar `null` antes
- ❌ `enum` numérico — usar `as const` + `typeof` ou string unions
- ❌ `Function` type — usar signature explícita `(args: T) => R`
- ❌ `Object` / `{}` — usar `Record<string, unknown>` ou tipo específico
