---
name: Design System Engineering
description: Architect, build, scale, and govern design systems covering design token taxonomy (primitive → semantic → component), Atomic Design methodology, component API design, theming architecture, multi-platform distribution (Style Dictionary), accessibility integration, versioning strategy, and organizational governance. Concept-focused, applicable to any UI framework.
---

# Design System Engineering — Diretrizes Senior+

## 1. Princípio Fundamental

Um Design System NÃO é uma biblioteca de componentes. É um **produto** que serve outros produtos. Ele codifica decisões de design em artefatos reutilizáveis, garantindo **consistência, velocidade e qualidade** em escala.

> ⚠️ Criar componentes sem design tokens é decoração, não sistema. Criar tokens sem governança é caos organizado.

---

## 2. Anatomia de um Design System

```
┌────────────────────────────────────────────────────────┐
│                    DESIGN SYSTEM                       │
│                                                        │
│  ┌─────────────────────────────────────────────────┐  │
│  │  1. FOUNDATIONS (Design Tokens)                  │  │
│  │  Colors, Typography, Spacing, Shadows, Motion    │  │
│  │  Breakpoints, Borders, Z-index, Opacity          │  │
│  └──────────────────────┬──────────────────────────┘  │
│                         │ consomem                     │
│  ┌──────────────────────▼──────────────────────────┐  │
│  │  2. CORE COMPONENTS (Atoms + Molecules)          │  │
│  │  Button, Input, Badge, Checkbox, Avatar           │  │
│  │  Form Field, Search Bar, Card Header              │  │
│  └──────────────────────┬──────────────────────────┘  │
│                         │ compõem                      │
│  ┌──────────────────────▼──────────────────────────┐  │
│  │  3. PATTERNS (Organisms + Templates)             │  │
│  │  DataTable, Sidebar, PageHeader, CrudDrawer       │  │
│  │  LoginForm, DashboardLayout, SettingsPage          │  │
│  └──────────────────────┬──────────────────────────┘  │
│                         │ informam                     │
│  ┌──────────────────────▼──────────────────────────┐  │
│  │  4. DOCUMENTATION & GOVERNANCE                   │  │
│  │  Storybook, Guidelines, Contribution flow         │  │
│  │  Versioning, Changelog, Deprecation policy        │  │
│  └─────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

---

## 3. Design Tokens — Taxonomia de 3 Camadas

### 3.1 Hierarquia Obrigatória

```
┌── Layer 1: PRIMITIVE (Global) ──────────────────────┐
│  Valores crus sem contexto. Paleta bruta.            │
│  --blue-50: #eff6ff                                  │
│  --blue-500: #3b82f6                                 │
│  --blue-900: #1e3a5f                                 │
│  --font-size-14: 0.875rem                            │
│  --space-4: 1rem                                     │
│  --radius-md: 0.375rem                               │
└──────────────────────┬──────────────────────────────┘
                       │ referenciados por
┌──────────────────────▼──────────────────────────────┐
│  Layer 2: SEMANTIC (Alias)                           │
│  Propósito/significado. Mapeiam primitivos.          │
│  --color-brand: var(--blue-500)                      │
│  --color-bg: var(--gray-50)         ← Light mode     │
│  --color-bg: var(--gray-900)        ← Dark mode      │
│  --color-success: var(--green-500)                   │
│  --color-danger: var(--red-500)                      │
│  --text-body: var(--font-size-14)                    │
│  --spacing-default: var(--space-4)                   │
└──────────────────────┬──────────────────────────────┘
                       │ consumidos por
┌──────────────────────▼──────────────────────────────┐
│  Layer 3: COMPONENT                                  │
│  Específicos de cada componente.                     │
│  --btn-bg: var(--color-brand)                        │
│  --btn-padding-x: var(--space-4)                     │
│  --btn-radius: var(--radius-md)                      │
│  --btn-text: var(--color-on-brand)                   │
│  --card-border: var(--color-border)                  │
│  --card-shadow: var(--shadow-sm)                     │
└─────────────────────────────────────────────────────┘
```

### 3.2 Regras de Naming

```
CERTO: Naming semântico (por propósito)
--color-text-primary       ← texto principal
--color-text-secondary     ← texto auxiliar
--color-surface-elevated   ← card/modal background
--color-interactive        ← elementos clicáveis
--color-interactive-hover  ← hover de interativos

ERRADO: Naming literal (por aparência)
--dark-blue                ← o que é "dark"?
--heading-color            ← qual heading?
--card-gray                ← e se mudar para outro tema?
```

### 3.3 Tokens Obrigatórios Mínimos (~25 tokens)

| Categoria | Tokens | Descrição |
|---|---|---|
| **Color** | bg, fg, brand, surface, border, muted, success, danger, warning, info | 10 cores semânticas |
| **Typography** | font-family (2), size-sm, size-base, size-lg, size-xl, leading, tracking | 8 tokens tipo |
| **Spacing** | space-1 a space-12 | Escala 4px base |
| **Shape** | radius-sm, radius-md, radius-lg, radius-full | 4 border-radius |
| **Shadow** | shadow-sm, shadow-md, shadow-lg | 3 elevações |
| **Motion** | duration-fast (150ms), duration-normal (250ms), duration-slow (500ms), easing | 4 tokens motion |

---

## 4. Atomic Design — Metodologia

### 4.1 Níveis de Composição

```
ATOMS → MOLECULES → ORGANISMS → TEMPLATES → PAGES

Atoms:      Button, Input, Label, Icon, Badge, Avatar, Separator
Molecules:  FormField (Label + Input + Error), SearchBar, CardHeader
Organisms:  DataTable, Sidebar, PageHeader, CrudDrawer, LoginForm
Templates:  DashboardLayout, SettingsLayout, AuthLayout
Pages:      instance de Template com dados reais
```

### 4.2 Regras de Composição

- ✅ Atom NUNCA depende de outro Atom contextualmente
- ✅ Molecule combina 2+ Atoms com comportamento coeso
- ✅ Organism é auto-suficiente (pode funcionar isolado)
- ✅ Template define layout/grid sem dados reais
- ✅ Page é Template + data binding + business logic
- ❌ NUNCA colocar business logic em Atoms/Molecules
- ❌ NUNCA criar Atom com layout/grid (Atom é inline/flex-item)
- ❌ NUNCA pular nível (Page usando Atom direto sem Molecule/Organism)

---

## 5. Component API Design

### 5.1 Princípios de API

1. **Consistência**: Mesma prop = mesmo comportamento em todos os componentes
2. **Minimal Surface**: Menor número de props para cobrir 90% dos casos
3. **Composição > Configuração**: Preferir children/slots a props complexas
4. **Extensibilidade**: Permitir override via className/style/passthrough
5. **Tipagem**: TypeScript strict em toda prop

### 5.2 Props Universais (todo componente DEVE aceitar)

| Prop | Tipo | Obrigatória | Descrição |
|---|---|---|---|
| `className` | `string` | Sim | Override de CSS |
| `style` | `CSSProperties` | Sim | Inline styles |
| `id` | `string` | Não | ID para testes/a11y |
| `data-testid` | `string` | Não | Selector para E2E |
| `aria-*` | `string` | Não | Acessibilidade |

### 5.3 Variant Pattern

```
CERTO: Variant como enum
<Button variant="primary" size="md" />
<Button variant="destructive" size="sm" />
<Badge variant="success" />

ERRADO: Boolean explosion
<Button primary />
<Button destructive />
<Button large primary outlined />  ← combinação impossível de manter
```

### 5.4 Composição via Slots/Children

```
CERTO: Composição flexível
<Card>
  <CardHeader>
    <CardTitle>Título</CardTitle>
    <CardDescription>Descrição</CardDescription>
  </CardHeader>
  <CardContent>
    conteúdo flexível aqui
  </CardContent>
</Card>

ERRADO: Props para tudo
<Card
  title="Título"
  description="Descrição"
  content={<p>conteúdo</p>}
  footer={<Button>Salvar</Button>}
/>
```

---

## 6. Theming Architecture

### 6.1 CSS Custom Properties (Recomendado)

```css
/* Base: variáveis que TODOS os temas definem */
:root {
  --color-bg: #ffffff;
  --color-fg: #1a1a1a;
  --color-brand: #3b82f6;
}

/* Dark theme override */
[data-theme="dark"] {
  --color-bg: #0a0a0a;
  --color-fg: #fafafa;
  --color-brand: #60a5fa;
}

/* High contrast theme */
[data-theme="high-contrast"] {
  --color-bg: #000000;
  --color-fg: #ffffff;
  --color-brand: #ffff00;
}

/* Componentes usam APENAS tokens semânticos */
.btn-primary {
  background: var(--color-brand);
  color: var(--color-on-brand);
}
```

### 6.2 Multi-Brand Theming

```
Para SaaS multi-tenant com branding customizado:

1. Definir "theme contract" — lista de tokens obrigatórios
2. Cada tenant fornece valores para o contrato
3. CSS variables injetadas em runtime via style attribute
4. Fallback para tema padrão se token faltante

<div style="--color-brand: ${tenant.primaryColor}">
  <!-- Todo o app herda o branding do tenant -->
</div>
```

---

## 7. Multi-Platform Distribution

### 7.1 Style Dictionary / Token Pipeline

```
                    ┌──────────────────┐
                    │  tokens.json     │ ← Source of Truth
                    │  (platform-      │
                    │   agnostic)      │
                    └────────┬─────────┘
                             │ Style Dictionary / Cobalt
            ┌────────────────┼────────────────┐
            ▼                ▼                ▼
    ┌───────────┐    ┌───────────┐    ┌───────────┐
    │  Web      │    │  iOS      │    │  Android  │
    │  CSS vars │    │  Swift    │    │  Kotlin   │
    │  SCSS     │    │  .plist   │    │  .xml     │
    └───────────┘    └───────────┘    └───────────┘
```

### 7.2 Token Source Format

```json
{
  "color": {
    "primitive": {
      "blue": {
        "500": { "$value": "#3b82f6", "$type": "color" }
      }
    },
    "semantic": {
      "brand": { "$value": "{color.primitive.blue.500}", "$type": "color" },
      "bg": {
        "$value": "#ffffff",
        "$type": "color",
        "$extensions": {
          "mode": {
            "dark": "#0a0a0a"
          }
        }
      }
    }
  }
}
```

---

## 8. Governança & Lifecycle

### 8.1 Contribution Workflow

```
1. REQUEST: Designer/Dev propõe novo componente/token
2. REVIEW: Design System team avalia necessidade
   - Já existe componente similar?
   - Será usado por 2+ produtos?
   - Segue os tokens existentes?
3. DESIGN: Figma specfication com todos os estados
4. DEVELOP: Implementação + Storybook stories
5. TEST: Unit tests + Visual regression + a11y audit
6. DOCUMENT: Props, examples, dos/don'ts, a11y notes
7. RELEASE: Semantic version + changelog
8. COMMUNICATE: Newsletter/Slack notification
```

### 8.2 Semantic Versioning para DS

| Tipo | Versão | Quando |
|---|---|---|
| **Patch** (0.0.X) | Fix: bug no componente, ajuste visual | 1.2.**3** |
| **Minor** (0.X.0) | Add: novo componente, nova prop | 1.**3**.0 |
| **Major** (X.0.0) | Breaking: remover prop, mudar token name | **2**.0.0 |

### 8.3 Deprecation Policy

```
1. Marcar como @deprecated no código (JSDoc/Rustdoc)
2. Console.warn em dev mode com migration path
3. Documentar na página do componente: "Substituir por X"
4. Manter por mínimo 2 minor releases
5. Remover apenas em major release
```

---

## 9. Acessibilidade Integrada

Cada componente do DS DEVE nascer acessível:

| Requisito | Implementação |
|---|---|
| **Focus management** | `:focus-visible` com outline visível |
| **Color contrast** | 4.5:1 texto, 3:1 UI (validado com tokens) |
| **Keyboard** | Toda interação funciona sem mouse |
| **ARIA** | Roles corretos, labels, states |
| **Motion** | `prefers-reduced-motion` respeitado |
| **Responsive text** | `rem` / `clamp()`, nunca `px` fixo |

---

## 10. Checklist de Qualidade

### Para cada novo token:
- [ ] Naming segue padrão semântico (propósito, não aparência)
- [ ] Funciona em Light e Dark mode
- [ ] Contraste >= 4.5:1 para texto sobre fundo
- [ ] Documentado com uso esperado

### Para cada novo componente:
- [ ] Usa APENAS tokens semânticos (nunca hardcoded)
- [ ] TypeScript strict (zero `any`)
- [ ] Funciona com keyboard-only
- [ ] ARIA roles e labels corretos
- [ ] Storybook stories para cada variante
- [ ] Visual regression test baseline
- [ ] Respeita `prefers-reduced-motion`
- [ ] Documentado: props, examples, dos/don'ts

---

## 11. Dogmas

### NUNCA
- ❌ NUNCA usar cor hardcoded em componente — sempre token
- ❌ NUNCA criar componente sem definir sua API de props primeiro
- ❌ NUNCA lançar componente sem Storybook story
- ❌ NUNCA fazer breaking change em patch/minor release
- ❌ NUNCA criar componente "one-off" no design system (2+ consumers)
- ❌ NUNCA duplicar lógica entre componentes — extrair util/hook
- ❌ NUNCA ignorar acessibilidade "para depois"
- ❌ NUNCA over-tokenizar — se o valor é usado 1x, não precisa de token

### SEMPRE
- ✅ SEMPRE organizar tokens em 3 camadas (primitive → semantic → component)
- ✅ SEMPRE documentar decisões de design com os/don'ts
- ✅ SEMPRE testar componente em Light e Dark mode
- ✅ SEMPRE versionamento semântico com changelog
- ✅ SEMPRE composição via children/slots, não props-mega
- ✅ SEMPRE prefixar tokens de tema (app-specific) vs sistema

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.
