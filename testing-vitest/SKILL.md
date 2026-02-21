---
name: Testing (Vitest / Playwright)
description: Validate, generate, and enforce testing patterns using Vitest for unit/integration tests and Playwright for E2E. Covers AAA pattern, test factories, mocking boundaries, coverage thresholds, and CI integration.
---

# Testing — Diretrizes Sênior

## 1. Zero-Trust & Limites de Contexto

- **Antes de escrever testes**, definir a estratégia (unit vs integration vs E2E) em artefato.
- Faça **micro-commits**: escreva testes para um módulo por vez.
- **Mocke APENAS fronteiras externas** (DB, APIs, filesystem). Nunca mockar lógica interna.
- Testes devem rodar em < 30s (unit) e < 5min (E2E). Se ultrapassar, otimize.

## 2. Estrutura de Projeto

```
src/
├── services/
│   ├── user.service.ts
│   └── user.service.spec.ts     # Vitest — co-located
tests/
├── integration/
│   └── api/user.test.ts          # Testes de API
├── e2e/
│   └── auth.spec.ts              # Playwright E2E
├── factories/
│   └── user.factory.ts           # Test factories
└── setup.ts                      # Global setup
```

## 3. Vitest — Dogmas

### 3.1 Padrão AAA (Arrange-Act-Assert)

```typescript
// ✅ CERTO — AAA claro, descritivo, isolado
describe("UserService", () => {
  it("should throw when creating user with duplicate email", async () => {
    // Arrange
    const service = new UserService(mockRepo);
    await service.create({ email: "ana@test.com", name: "Ana" });

    // Act & Assert
    await expect(
      service.create({ email: "ana@test.com", name: "Ana 2" }),
    ).rejects.toThrow("Email já cadastrado");
  });
});

// ❌ ERRADO — sem estrutura, nome genérico
it("test user", async () => {
  const result = await service.create({ email: "a@b.com", name: "x" });
  expect(result).toBeTruthy(); // Asserta quase nada
});
```

### 3.2 Mock apenas fronteiras

```typescript
// ✅ CERTO — mock do repository (fronteira com DB)
import { vi } from "vitest";

const mockUserRepo = {
  findByEmail: vi.fn(),
  create: vi.fn(),
};

describe("UserService", () => {
  const service = new UserService(mockUserRepo);

  it("should create user when email is unique", async () => {
    mockUserRepo.findByEmail.mockResolvedValue(null);
    mockUserRepo.create.mockResolvedValue({ id: "1", email: "ana@test.com" });

    const result = await service.create({ email: "ana@test.com", name: "Ana" });

    expect(mockUserRepo.create).toHaveBeenCalledWith({
      email: "ana@test.com",
      name: "Ana",
    });
    expect(result.id).toBe("1");
  });
});

// ❌ ERRADO — mock da lógica interna (testa implementação, não comportamento)
vi.spyOn(service, "validateEmail").mockReturnValue(true);
// Se refatorar validateEmail, o teste quebra sem razão!
```

### 3.3 Test Factories

```typescript
// ✅ CERTO — factory com defaults e overrides
import { faker } from "@faker-js/faker";

export function buildUser(overrides: Partial<User> = {}): User {
  return {
    id: faker.string.uuid(),
    name: faker.person.fullName(),
    email: faker.internet.email(),
    status: "active",
    createdAt: new Date(),
    ...overrides,
  };
}

// Uso:
const activeUser = buildUser();
const inactiveUser = buildUser({ status: "inactive" });
const specificUser = buildUser({ email: "ana@test.com" });

// ❌ ERRADO — dados hardcoded em cada teste
const user = {
  id: "1",
  name: "Test",
  email: "test@test.com",
  status: "active",
};
// Duplicado em 50 testes — muda interface, quebra todos
```

## 4. Playwright — E2E

```typescript
// ✅ CERTO — page object pattern, data-testid, cleanup
import { test, expect } from "@playwright/test";

test.describe("Login Flow", () => {
  test("should login with valid credentials", async ({ page }) => {
    await page.goto("/login");

    await page.getByTestId("email-input").fill("admin@test.com");
    await page.getByTestId("password-input").fill("SecureP@ss1");
    await page.getByTestId("login-button").click();

    await expect(page.getByTestId("dashboard-title")).toBeVisible();
    await expect(page).toHaveURL("/dashboard");
  });

  test("should show error on invalid password", async ({ page }) => {
    await page.goto("/login");

    await page.getByTestId("email-input").fill("admin@test.com");
    await page.getByTestId("password-input").fill("wrong");
    await page.getByTestId("login-button").click();

    await expect(page.getByTestId("error-message")).toContainText(
      "Credenciais inválidas",
    );
  });
});

// ❌ ERRADO — seletores frágeis, sem data-testid
await page.click(".btn-primary"); // Classe CSS pode mudar!
await page.fill('input[type="email"]', "..."); // Múltiplos inputs de email?
```

## 5. Coverage

```typescript
// vitest.config.ts
export default defineConfig({
  test: {
    coverage: {
      provider: "v8",
      reporter: ["text", "lcov"],
      thresholds: {
        branches: 80,
        functions: 80,
        lines: 80,
        statements: 80,
      },
      exclude: [
        "**/*.spec.ts",
        "**/*.test.ts",
        "**/factories/**",
        "**/types/**",
      ],
    },
  },
});
```

## 6. Anti-Patterns

- ❌ Testes que dependem de ordem de execução — cada teste deve ser independente
- ❌ `expect(result).toBeTruthy()` — assertar valores específicos
- ❌ Testes que chamam API real (flaky) — mock HTTP em unit tests
- ❌ `setTimeout` para esperar — usar `waitFor`, `expect.poll`, retries
- ❌ Ignorar cleanup — `afterEach(() => vi.restoreAllMocks())`
