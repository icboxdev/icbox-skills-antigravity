---
name: Playwright E2E & Visual Testing
description: Validate, generate, and optimize Playwright test suites for E2E flows, visual regression testing with toHaveScreenshot, layout validation, test fixtures, and CI integration with GitHub Actions.
---

# Playwright — E2E, Visual Regression & Layout Testing

## 1. Propósito

Gerar e validar testes E2E com Playwright para garantir que fluxos de usuário, layouts e componentes visuais funcionam corretamente. Cobre visual regression (screenshots), layout testing (viewport), fixtures reutilizáveis e CI integration.

## 2. Dogmas Arquiteturais

### Locators > Selectors

**NUNCA** usar `page.$("div.class")` ou XPath. **SEMPRE** usar Role-based locators (`getByRole`, `getByLabel`, `getByText`) para testes resilientes e acessíveis.

### Auto-Wait é seu Amigo

**NUNCA** usar `page.waitForTimeout()` (sleep). Playwright auto-waits em locators e assertions. Use `expect(locator).toBeVisible()` ao invés de delays.

### Test Isolation

Cada teste deve ser independente. **NUNCA** depender do estado de um teste anterior. Use fixtures para setup.

### Visual Testing = Gated

Screenshots devem ser comparados com baseline. Se não houver baseline, o teste CRIA uma. Atualize baselines conscientemente.

## 3. Patterns Essenciais

### 3.1 Teste E2E Básico

```typescript
// CERTO — Locators semânticos, assertions auto-wait
import { test, expect } from "@playwright/test";

test("deve criar um novo usuário", async ({ page }) => {
  await page.goto("/users");

  await page.getByRole("button", { name: "Novo Usuário" }).click();

  await page.getByLabel("Nome").fill("João Silva");
  await page.getByLabel("E-mail").fill("joao@example.com");
  await page.getByRole("combobox", { name: "Perfil" }).click();
  await page.getByRole("option", { name: "Admin" }).click();

  await page.getByRole("button", { name: "Salvar" }).click();

  await expect(page.getByText("Usuário criado")).toBeVisible();
  await expect(page.getByRole("cell", { name: "João Silva" })).toBeVisible();
});
```

```typescript
// ERRADO — Selectors frágeis, sleeps manuais
test("criar usuario", async ({ page }) => {
  await page.goto("/users");
  await page.click(".btn-primary");           // Seletor frágil
  await page.fill("#name-input", "João");     // ID pode mudar
  await page.waitForTimeout(2000);            // Sleep = flaky
  await page.click("button[type=submit]");
  await page.waitForTimeout(1000);
  const text = await page.textContent(".toast");
  expect(text).toContain("criado");
});
```

### 3.2 Visual Regression Testing

```typescript
// CERTO — Screenshot comparison com threshold
test("layout da página de users", async ({ page }) => {
  await page.goto("/users");
  await page.waitForLoadState("networkidle");

  // Screenshot da página inteira
  await expect(page).toHaveScreenshot("users-page.png", {
    maxDiffPixelRatio: 0.01,  // 1% de tolerância
  });

  // Screenshot de componente específico
  const table = page.getByRole("table");
  await expect(table).toHaveScreenshot("users-table.png");
});

test("drawer de criação", async ({ page }) => {
  await page.goto("/users");
  await page.getByRole("button", { name: "Novo Usuário" }).click();

  const drawer = page.getByRole("dialog");
  await expect(drawer).toHaveScreenshot("user-drawer.png");
});
```

### 3.3 Layout Testing (Viewport)

```typescript
// CERTO — Testar responsividade
const viewports = [
  { name: "mobile", width: 375, height: 812 },
  { name: "tablet", width: 768, height: 1024 },
  { name: "desktop", width: 1440, height: 900 },
];

for (const vp of viewports) {
  test(`layout ${vp.name}`, async ({ page }) => {
    await page.setViewportSize({ width: vp.width, height: vp.height });
    await page.goto("/dashboard");
    await expect(page).toHaveScreenshot(`dashboard-${vp.name}.png`);
  });
}
```

### 3.4 Fixtures Reutilizáveis

```typescript
// CERTO — Fixture para autenticação
import { test as base } from "@playwright/test";

type Fixtures = {
  authenticatedPage: Page;
};

export const test = base.extend<Fixtures>({
  authenticatedPage: async ({ page }, use) => {
    await page.goto("/login");
    await page.getByLabel("E-mail").fill("admin@test.com");
    await page.getByLabel("Senha").fill("password123");
    await page.getByRole("button", { name: "Entrar" }).click();
    await page.waitForURL("/dashboard");
    await use(page);
  },
});

// Usar nos testes
test("acessar settings", async ({ authenticatedPage: page }) => {
  await page.goto("/settings");
  await expect(page.getByRole("heading", { name: "Configurações" })).toBeVisible();
});
```

### 3.5 CI Configuration

```yaml
# .github/workflows/playwright.yml
name: Playwright Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm ci
      - run: npx playwright install --with-deps
      - run: npx playwright test
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: playwright-report
          path: playwright-report/
```

## 4. Config Recomendada

```typescript
// playwright.config.ts
import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: "html",
  use: {
    baseURL: "http://localhost:3000",
    trace: "on-first-retry",
    screenshot: "only-on-failure",
  },
  projects: [
    { name: "chromium", use: { ...devices["Desktop Chrome"] } },
    { name: "mobile", use: { ...devices["iPhone 14"] } },
  ],
  webServer: {
    command: "npm run dev",
    port: 3000,
    reuseExistingServer: !process.env.CI,
  },
});
```

## 5. Zero-Trust

- **NUNCA** usar `waitForTimeout` — é o sinal mais claro de teste frágil.
- **NUNCA** hardcodar URLs absolutas — usar `baseURL` da config.
- **NUNCA** ignorar testes flaky — investigar e corrigir a causa raiz.
- **SEMPRE** usar `getByRole`, `getByLabel`, `getByText` — nunca CSS selectors.
- **SEMPRE** commitar baseline screenshots no repositório.
- **SEMPRE** revisar visualmente diffs de screenshots antes de atualizar baselines.
