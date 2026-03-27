---
name: Storybook Component Audit
description: Validate, document, and test design system components using Storybook stories, visual testing, docs addon, accessibility addon, and component isolation patterns for React/Next.js.
---

# Storybook — Component Audit, Visual Testing & Design System Docs

## 1. Propósito

Documentar, testar isoladamente e validar visualmente todos os componentes do design system usando Storybook. Garante que componentes são reutilizáveis, acessíveis e visualmente consistentes.

## 2. Dogmas Arquiteturais

### Todo Componente Compartilhado tem Story

**NUNCA** criar um componente em `components/` sem uma story correspondente. Stories são a documentação viva do design system.

### Isolation First

**SEMPRE** testar componentes isolados de contexto (sem providers globais exceto os necessários). Se o componente não funciona isolado, tem acoplamento demais.

### Args > Props

**SEMPRE** usar `args` do Storybook para controlar props. Permite playground interativo para designers e devs.

## 3. Patterns Essenciais

### 3.1 Story Básica (CSF 3)

```typescript
// CERTO — Component Story Format 3
import type { Meta, StoryObj } from "@storybook/react";
import { Button } from "@/components/ui/button";

const meta: Meta<typeof Button> = {
  title: "UI/Button",
  component: Button,
  tags: ["autodocs"],
  argTypes: {
    variant: {
      control: "select",
      options: ["default", "destructive", "outline", "secondary", "ghost", "link"],
    },
    size: { control: "select", options: ["default", "sm", "lg", "icon"] },
    disabled: { control: "boolean" },
  },
};

export default meta;
type Story = StoryObj<typeof Button>;

export const Default: Story = {
  args: { children: "Button", variant: "default" },
};

export const Destructive: Story = {
  args: { children: "Deletar", variant: "destructive" },
};

export const WithIcon: Story = {
  args: { children: "Configurações" },
  render: (args) => (
    <Button {...args}>
      <Settings className="mr-2 h-4 w-4" />
      {args.children}
    </Button>
  ),
};
```

```typescript
// ERRADO — Story sem tipagem, sem argTypes
export const MyButton = () => <Button>Click</Button>;
// Sem controles, sem docs, sem playground
```

### 3.2 Componente Composto

```typescript
// CERTO — Story para componente composto (DataTable)
import type { Meta, StoryObj } from "@storybook/react";
import { DataTable } from "@/components/ui/data-table";

const sampleData = [
  { id: "1", name: "João", email: "joao@test.com", role: "Admin" },
  { id: "2", name: "Maria", email: "maria@test.com", role: "Membro" },
];

const columns = [
  { accessorKey: "name", header: "Nome" },
  { accessorKey: "email", header: "E-mail" },
  { accessorKey: "role", header: "Perfil" },
];

const meta: Meta<typeof DataTable> = {
  title: "Data/DataTable",
  component: DataTable,
  tags: ["autodocs"],
  decorators: [
    (Story) => (
      <div className="h-[400px] flex flex-col">
        <Story />
      </div>
    ),
  ],
};

export default meta;
type Story = StoryObj<typeof DataTable>;

export const Default: Story = {
  args: { columns, data: sampleData },
};

export const Empty: Story = {
  args: { columns, data: [] },
};

export const Loading: Story = {
  args: { columns, data: [], isLoading: true },
};
```

### 3.3 Accessibility Testing

```typescript
// CERTO — Story com a11y addon test
import { within, userEvent } from "@storybook/testing-library";
import { expect } from "@storybook/jest";

export const KeyboardNavigation: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    const button = canvas.getByRole("button", { name: "Salvar" });

    await userEvent.tab();
    expect(button).toHaveFocus();

    await userEvent.keyboard("{Enter}");
    expect(canvas.getByText("Salvo!")).toBeVisible();
  },
};
```

### 3.4 Dark Mode Testing

```typescript
// CERTO — Decorator para dark mode
const meta: Meta<typeof Card> = {
  title: "UI/Card",
  component: Card,
  decorators: [
    (Story, context) => (
      <div className={context.globals.theme === "dark" ? "dark" : ""}>
        <div className="bg-background text-foreground p-8">
          <Story />
        </div>
      </div>
    ),
  ],
};
```

## 4. Estrutura de Diretórios

```
src/
  components/
    ui/
      button.tsx
      button.stories.tsx       ← Co-location
    page-header.tsx
    page-header.stories.tsx    ← Co-location
  .storybook/
    main.ts
    preview.ts
```

## 5. Config Recomendada

```typescript
// .storybook/main.ts
import type { StorybookConfig } from "@storybook/nextjs";

const config: StorybookConfig = {
  stories: ["../src/**/*.stories.@(ts|tsx)"],
  addons: [
    "@storybook/addon-essentials",
    "@storybook/addon-a11y",
    "@storybook/addon-interactions",
  ],
  framework: "@storybook/nextjs",
};

export default config;
```

```typescript
// .storybook/preview.ts
import "@/app/globals.css";
import type { Preview } from "@storybook/react";

const preview: Preview = {
  globalTypes: {
    theme: {
      description: "Dark/Light mode",
      defaultValue: "dark",
      toolbar: { title: "Theme", items: ["light", "dark"], dynamicTitle: true },
    },
  },
  parameters: {
    layout: "centered",
    backgrounds: { disable: true },
  },
};

export default preview;
```

## 6. Zero-Trust

- **NUNCA** criar stories sem `tags: ["autodocs"]` — documentação é obrigatória.
- **NUNCA** usar dados hardcoded complexos inline — criar factories/fixtures.
- **NUNCA** skippar a11y addon — acessibilidade é testada em cada story.
- **SEMPRE** testar em dark e light mode.
- **SEMPRE** incluir stories para estados: default, loading, empty, error, disabled.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

