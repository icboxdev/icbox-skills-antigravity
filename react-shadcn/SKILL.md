---
name: React/Shadcn UI Frontend
description: Architect, generate, and validate React applications using the Shadcn UI library, Radix primitives, and Tailwind CSS. Enforces strict TypeScript, Server Actions validation, zero-trust component rendering, and utility classes composition (cn).
---

# React/Shadcn UI — Diretrizes de Engenharia

## 1. Princípio Zero: Memória e Controle de Destruição

- **Shadcn não é NPM**: Os componentes Shadcn vivem na pasta `/components/ui/`. **NUNCA** gere comandos para sobrescrevê-los via CLI (`npx shadcn@latest add ...`) sem antes checar se eles já existem e se foram customizados pelo usuário. Assuma que todo componente base é sagrado.
- **Externalize Decisões de UI**: Antes de arquitetar páginas React massivas, documente a estrutura de componentes no `/components/ARCHITECTURE.md`.

## 2. Componentização Avançada e Segurança (Zero-Trust)

### TypeScript Sênior

- `any` é terminantemente proibido.
- Se uma variável vem de uma API ou _Server Action_, ela não é segura. O tipo inicial é `unknown` até que a validação do Zod ocorra.

### Uso do Utilitário `cn()`

Sempre faça o merge seguro das propriedades CSS (Tailwind) usando `cn` (clsx + tailwind-merge) para garantir resolução de precedência.

#### Few-Shot: Construção de UI Segura

```tsx
// CERTO (Compondo a classe de fora do componente controlando colisão)
import { cn } from "@/lib/utils";

interface CustomBoxProps extends React.HTMLAttributes<HTMLDivElement> {
  isActive?: boolean;
}

export function CustomBox({ className, isActive, ...props }: CustomBoxProps) {
  return (
    <div
      className={cn(
        "rounded-md border p-4 transition-colors",
        isActive ? "bg-primary text-primary-foreground" : "bg-transparent",
        className,
      )}
      {...props}
    />
  );
}

// ERRADO (Classes rígidas / concatenações com template string fracas)
export function CustomBox({ className, isActive }: CustomBoxProps) {
  return (
    <div
      className={`rounded-md border p-4 ${isActive ? "bg-primary" : ""} ${className}`}
    />
  );
}
```

## 3. Data Fetching e Validação em Server Actions

- O React 19/RSC muda o paradigma. Em projetos App Router, **Server Actions devem revalidar** o Zod Schema de input, mesmo que o forms cliente tenha validado. (Zero-Trust).
- Evite `useEffect` manual para carregar dados. Em Client Components, confie em Tanstack Query/SWR.

### Few-Shot: Validação de Server Action Segura

```typescript
// CERTO
"use server";

import { z } from "zod";

const formSchema = z.object({
  email: z.string().email(),
});

export async function submitLead(formData: FormData) {
  // A validação OCORRE de novo no backend
  const parsed = formSchema.safeParse({ email: formData.get("email") });

  if (!parsed.success) {
    return { error: "Input inválido" };
  }

  // Executa db mutation...
}

// ERRADO
("use server");

export async function submitLead(email: any) {
  // Confiando cegamente na String que veio da view
  await db.lead.create({ data: { email } });
}
```

## 4. Acessibilidade Imutável (a11y)

Você está proibido de remover tags `aria-` ou props subjacentes injetadas pelos primitivos do Radix UI.

## Resumo Operacional para Criação

Quando atuar como Engenheiro React + Shadcn:

1. Trabalhe em arquivos modulares (pequenos), não gigantes.
2. Use `cn()` para gerir classes dinâmicas.
3. Não presuma que Shadcn usa classes mágicas: injete utilitários limpos Tailwind.
