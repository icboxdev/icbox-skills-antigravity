---
name: Accessibility Testing Automation
description: Validate, automate, and enforce accessibility testing using axe-core (jest-axe, vitest-axe), Pa11y CI, Lighthouse CI, Playwright (@axe-core/playwright), React Testing Library (screen queries, role-based selectors), and WCAG 2.2 compliance checks. Covers unit, integration, and E2E accessibility testing in CI/CD pipelines with build failure thresholds.
---

# Accessibility Testing Automation — Diretrizes Senior+

## 0. Princípio Fundamental: A11y É Testável

Acessibilidade não é "sensação" — é **mensurável e automatizável**:
- Ferramentas automatizadas detectam ~40-57% dos problemas WCAG.
- O resto requer testes manuais + assistive technology.
- Automatize o que pode, teste manualmente o que não pode, NUNCA ignore.

> ⚠️ **Crime**: Deploy sem nenhum teste de acessibilidade automatizado. É como deploy sem testes de tipo — acidentes esperando para acontecer.

---

## 1. Estratégia de Testes em Camadas

```
┌──────────────────────────────────────────────────────────────────┐
│ Camada        │ Ferramenta            │ O Que Testa             │
├───────────────┼───────────────────────┼─────────────────────────┤
│ Lint (dev)    │ eslint-plugin-jsx-a11y│ ARIA inválido, alt, role│
│ Unit          │ vitest-axe + RTL      │ Componentes isolados    │
│ Integration   │ @axe-core/playwright  │ Páginas renderizadas    │
│ E2E           │ Playwright + axe      │ Fluxos completos        │
│ CI/CD         │ Pa11y CI + Lighthouse │ Regressão contínua      │
│ Manual        │ Screen reader + teclado│ UX real, contexto      │
└───────────────┴───────────────────────┴─────────────────────────┘
```

---

## 2. Unit Tests — Componentes (vitest-axe)

```typescript
// CERTO: testar acessibilidade de componente com vitest-axe
import { render } from '@testing-library/react';
import { axe, toHaveNoViolations } from 'jest-axe';
import { describe, it, expect } from 'vitest';
import { Button } from '@/components/ui/button';
import { Dialog } from '@/components/ui/dialog';

expect.extend(toHaveNoViolations);

describe('Button a11y', () => {
  it('should have no accessibility violations', async () => {
    const { container } = render(
      <Button onClick={() => {}}>Salvar contato</Button>
    );
    const results = await axe(container);
    expect(results).toHaveNoViolations();
  });

  it('icon-only button must have aria-label', async () => {
    const { container } = render(
      <Button size="icon" aria-label="Fechar menu">
        <XIcon />
      </Button>
    );
    const results = await axe(container);
    expect(results).toHaveNoViolations();
  });
});

describe('Dialog a11y', () => {
  it('should have proper ARIA attributes when open', async () => {
    const { container } = render(
      <Dialog open>
        <Dialog.Content aria-labelledby="dialog-title">
          <h2 id="dialog-title">Confirmar exclusão</h2>
          <p>Tem certeza que deseja excluir?</p>
          <Button>Cancelar</Button>
          <Button>Excluir</Button>
        </Dialog.Content>
      </Dialog>
    );
    const results = await axe(container);
    expect(results).toHaveNoViolations();
  });
});

// ERRADO: componente sem aria-label em botão de ícone
// ERRADO: dialog sem aria-labelledby — screen reader não anuncia
// ERRADO: testar apenas snapshot visual sem axe
```

---

## 3. Integration Tests — Páginas (Playwright + axe)

```typescript
// CERTO: testar página inteira com @axe-core/playwright
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test.describe('Contacts page a11y', () => {
  test('should have no WCAG 2.2 AA violations', async ({ page }) => {
    await page.goto('/contacts');
    await page.waitForSelector('[data-testid="contacts-table"]');

    const accessibilityScanResults = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag22aa']) // WCAG 2.2 AA
      .analyze();

    expect(accessibilityScanResults.violations).toEqual([]);
  });

  test('should be navigable by keyboard', async ({ page }) => {
    await page.goto('/contacts');

    // Tab para o primeiro botão
    await page.keyboard.press('Tab');
    const focused = await page.evaluate(() => document.activeElement?.tagName);
    expect(focused).toBeTruthy();

    // Enter ativa o botão focado
    await page.keyboard.press('Enter');
    // Verificar que ação aconteceu
  });

  test('should announce page title to screen readers', async ({ page }) => {
    await page.goto('/contacts');

    const h1 = await page.locator('h1').first();
    await expect(h1).toBeVisible();
    await expect(h1).toHaveText(/contatos/i);
  });
});

// ERRADO: testar apenas E2E funcional sem verificação de a11y
// ERRADO: ignorar violations com disable() em vez de corrigir
```

---

## 4. React Testing Library — Queries Acessíveis

```typescript
// CERTO: usar queries que refletem como assistive tech encontra elementos
import { render, screen } from '@testing-library/react';

// ✅ PRIORIDADE 1: queries semânticas (como screen reader encontra)
screen.getByRole('button', { name: 'Salvar contato' });
screen.getByRole('heading', { level: 1 });
screen.getByRole('textbox', { name: 'Email' });
screen.getByRole('dialog', { name: 'Confirmar exclusão' });
screen.getByRole('navigation');
screen.getByRole('table');

// ✅ PRIORIDADE 2: label text
screen.getByLabelText('Nome completo');

// ✅ PRIORIDADE 3: placeholder (se label não existe)
screen.getByPlaceholderText('Buscar...');

// ✅ PRIORIDADE 4: texto visível
screen.getByText('Nenhum contato encontrado');

// ❌ EVITAR: data-testid (só como último recurso)
screen.getByTestId('contact-row'); // usar getByRole('row') se possível

// ERRADO: querySelector('.my-class') — ignora semântica
// ERRADO: getByTestId para tudo — não valida acessibilidade
```

---

## 5. CI/CD Pipeline — Automação

### 5.1 GitHub Actions

```yaml
# .github/workflows/a11y.yml
name: Accessibility Tests

on: [push, pull_request]

jobs:
  a11y-unit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm ci
      - run: npm run test:a11y  # vitest com jest-axe

  a11y-e2e:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm ci
      - run: npx playwright install --with-deps
      - run: npm run build
      - run: npm run start &
      - run: npx wait-on http://localhost:3000
      - run: npx playwright test --grep @a11y  # testes marcados com @a11y

  lighthouse:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm ci && npm run build && npm run start &
      - run: npx wait-on http://localhost:3000
      - name: Lighthouse CI
        run: |
          npx @lhci/cli autorun \
            --collect.url=http://localhost:3000 \
            --assert.preset=lighthouse:recommended \
            --assert.assertions.categories:accessibility=error \
            --assert.assertions.categories:accessibility.minScore=0.9
        # FALHAR build se accessibility score < 90
```

### 5.2 Pa11y CI Config

```json
// .pa11yci.json
{
  "defaults": {
    "timeout": 30000,
    "standard": "WCAG2AA",
    "runners": ["axe", "htmlcs"],
    "chromeLaunchConfig": {
      "args": ["--no-sandbox"]
    }
  },
  "urls": [
    "http://localhost:3000/",
    "http://localhost:3000/login",
    "http://localhost:3000/contacts",
    "http://localhost:3000/deals",
    "http://localhost:3000/settings"
  ]
}
```

---

## 6. ESLint — Lint em Dev

```javascript
// .eslintrc.js — regras de acessibilidade
module.exports = {
  plugins: ['jsx-a11y'],
  extends: ['plugin:jsx-a11y/recommended'],
  rules: {
    // Stricto: error em vez de warning
    'jsx-a11y/alt-text': 'error',
    'jsx-a11y/anchor-has-content': 'error',
    'jsx-a11y/aria-props': 'error',
    'jsx-a11y/aria-role': 'error',
    'jsx-a11y/aria-unsupported-elements': 'error',
    'jsx-a11y/click-events-have-key-events': 'error',
    'jsx-a11y/heading-has-content': 'error',
    'jsx-a11y/label-has-associated-control': 'error',
    'jsx-a11y/no-autofocus': 'warn', // permitir em modais
    'jsx-a11y/no-noninteractive-element-interactions': 'error',
  },
};

// ERRADO: eslint-disable jsx-a11y/* — esconder problema não resolve
// ERRADO: rules como 'warn' — ninguém corrige warnings
```

---

## 7. Scripts de Teste — package.json

```json
{
  "scripts": {
    "test:a11y": "vitest run --reporter=verbose tests/a11y/",
    "test:a11y:watch": "vitest watch tests/a11y/",
    "test:a11y:e2e": "playwright test --grep @a11y",
    "test:lighthouse": "lhci autorun",
    "test:pa11y": "pa11y-ci",
    "test:all:a11y": "npm run test:a11y && npm run test:a11y:e2e && npm run test:pa11y"
  }
}
```

---

## 8. WCAG 2.2 — Novidades a Testar

```
Novos critérios WCAG 2.2 (automatizáveis parcialmente):

✅ Focus Appearance (2.4.11 AA)
   → Indicador de foco visível com mínimo 2px de contraste
   → Testar: outline-offset, border, box-shadow em :focus-visible

✅ Dragging Movements (2.5.7 AA)
   → Alternativa sem arrastar para toda funcionalidade drag-and-drop
   → Testar: botões alternativos em Kanban/grid layout

✅ Target Size (2.5.8 AA)
   → Área de toque mínima 24x24px
   → Testar: min-width/min-height em botões, links, inputs

✅ Accessible Authentication (3.3.8 AA)
   → Login sem teste cognitivo (CAPTCHA, lembrar senha)
   → Testar: autocomplete em campos de login, biometria, passkeys
```

---

## 9. Checklist — A11y Testing

- [ ] **eslint-plugin-jsx-a11y** — configurado como error, não warn.
- [ ] **vitest-axe** — componentes testados com `toHaveNoViolations()`.
- [ ] **RTL queries semânticas** — `getByRole` como prioridade 1.
- [ ] **Playwright + axe** — páginas testadas com WCAG 2.2 AA tags.
- [ ] **Keyboard navigation** — Tab, Enter, Escape testados em E2E.
- [ ] **Lighthouse CI** — score a11y ≥ 90, build falha se abaixo.
- [ ] **Pa11y CI** — URLs principais validadas em cada PR.
- [ ] **Focus visible** — indicador de foco com 2px+ contraste.
- [ ] **Target size** — elementos interativos ≥ 24x24px.
- [ ] **Alt text** — toda imagem tem alt descritivo (ou alt="" se decorativa).
- [ ] **aria-label** — botões de ícone, links ambíguos, inputs sem label.
- [ ] **Heading hierarchy** — h1 único por página, sem pular níveis.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

