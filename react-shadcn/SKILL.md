---
name: React/Shadcn UI Frontend
description: Architect, generate, and validate React applications using the Shadcn UI library, Radix primitives, and Tailwind CSS. Enforces strict TypeScript, Server Actions validation, zero-trust component rendering, and utility classes composition (cn).
---

# React/Shadcn UI — Diretrizes Sênior

## 1. Princípio Zero: Memória e Controle de Destruição

- **Shadcn não é NPM**: Os componentes Shadcn vivem na pasta `/components/ui/`. **NUNCA** gere comandos para sobrescrevê-los via CLI (`npx shadcn@latest add ...`) sem antes checar se eles já existem e se foram customizados pelo usuário.
- **Externalize Decisões de UI**: Documente a estrutura de componentes em `ARCHITECTURE.md`.
- **Skills complementares**: SEMPRE leia `zustand-state`, `tanstack-query`, `a11y-wcag` e `web-design-uiux` junto.

## 2. Componentização Avançada e Segurança (Zero-Trust)

### TypeScript Sênior

- `any` é terminantemente proibido.
- Se uma variável vem de uma API, ela é `unknown` até validação Zod.
- Props devem ser interfaces, nunca `type` inline.

### Uso do Utilitário `cn()`

```tsx
// CERTO: cn() para merge seguro de classes
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

// ERRADO: Template string sem merge
className={`rounded-md ${isActive ? "bg-primary" : ""} ${className}`}
```

## 3. Data Fetching — Separação de Responsabilidades

```
Client State (Zustand)     → auth, sidebar, modals, theme, WebSocket
Server State (TanStack Query) → contacts, deals, pipelines, activities
```

### Padrão de Hook por Feature

```typescript
// features/contacts/hooks/useContacts.ts
import { useQuery } from '@tanstack/react-query'
import { contactKeys } from '@/lib/queryKeys'
import { api } from '@/lib/api'

export function useContacts(filters: ContactFilters) {
  return useQuery({
    queryKey: contactKeys.list(filters),
    queryFn: () => api.get('/contacts', { params: filters }),
    select: (data) => data.data,
  })
}
```

### NUNCA faça fetch no useEffect

```tsx
// ERRADO
useEffect(() => {
  fetch('/api/contacts').then(r => r.json()).then(setContacts)
}, [])

// CERTO
const { data: contacts, isLoading } = useContacts(filters)
```

## 4. Formulários — React Hook Form + Zod

```tsx
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'

const schema = z.object({
  name: z.string().min(2, 'Nome deve ter no mínimo 2 caracteres'),
  email: z.string().email('Email inválido').optional(),
  phone: z.string().regex(/^\+?\d{10,15}$/, 'Telefone inválido'),
})

type FormData = z.infer<typeof schema>

export function ContactForm({ onSubmit }: { onSubmit: (data: FormData) => void }) {
  const form = useForm<FormData>({
    resolver: zodResolver(schema),
    defaultValues: { name: '', email: '', phone: '' },
  })

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)}>
        <FormField
          control={form.control}
          name="name"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Nome</FormLabel>
              <FormControl>
                <Input {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
        {/* ... */}
        <Button type="submit" disabled={form.formState.isSubmitting}>
          Salvar
        </Button>
      </form>
    </Form>
  )
}
```

## 5. Padrão de Página — Component Architecture (3 Camadas)

```
Camada 1: packages/ui/components/ → PageHeader, DataTable, CrudDrawer, ConfirmDialog
Camada 2: packages/ui/templates/ → TablePageTemplate, FormPageTemplate, KanbanPageTemplate
Camada 3: apps/*/pages/          → Composição de templates + hooks (ZERO HTML raw)
```

```tsx
// CERTO: Página composta de template + hook
export function ContactsPage() {
  const { data, isLoading } = useContacts(filters)
  const createMutation = useCreateContact()

  return (
    <TablePageTemplate
      title="Contatos"
      description="Gerencie seus contatos"
      data={data?.items ?? []}
      columns={contactColumns}
      isLoading={isLoading}
      onAdd={() => setDrawerOpen(true)}
      pagination={data?.meta}
    />
  )
}

// ERRADO: Página com HTML raw e lógica misturada
export function ContactsPage() {
  return (
    <div className="p-6">
      <h1>Contatos</h1>
      <table>...</table>
    </div>
  )
}
```

## 6. Toasts & Notifications

```typescript
import { toast } from 'sonner'

// Em mutations
const createMutation = useCreateContact()

const handleSubmit = (data: CreateContactDto) => {
  createMutation.mutate(data, {
    onSuccess: () => {
      toast.success('Contato criado com sucesso')
      setDrawerOpen(false)
    },
    onError: (error) => {
      toast.error(error.response?.data?.error?.message || 'Erro ao criar contato')
    },
  })
}
```

## 7. Acessibilidade Imutável (a11y)

- NUNCA remova `aria-*` ou props do Radix UI.
- Todo input DEVE ter `<Label>` associado.
- Todo botão de ação destrutiva DEVE ter `<ConfirmDialog>` com descrição.
- Foco gerenciado em modals/drawers (trap focus).

## 8. Design Tokens & Tema

```css
/* Dark theme ICBox: */
--background: #09090B;
--card: #111113;
--sidebar: #0C0C0E;
--input: #1A1A1D;
--accent: #38BDF8;       /* Sky Blue */
--accent-gradient: linear-gradient(135deg, #38BDF8, #22D3EE);

/* Micro-animações: */
--duration-fast: 150ms;     /* hover glow */
--duration-normal: 200ms;   /* button press */
--duration-slow: 300ms;     /* drawer slide */
```

## Resumo Operacional

1. Trabalhe em arquivos modulares (< 200 linhas), nunca monolíticos.
2. Use `cn()` para gerir classes Tailwind dinâmicas.
3. Server state → TanStack Query. Client state → Zustand. NUNCA misture.
4. Toda página usa templates (Camada 2). Zero HTML raw.
5. React Hook Form + Zod em TODOS os formulários.
6. Sonner para toasts. Shadcn Dialog para confirmações.

## Constraints

- ❌ NUNCA use `any` — `unknown` + Zod
- ❌ NUNCA faça fetch em useEffect — use TanStack Query
- ❌ NUNCA crie componentes > 200 linhas — decomponha
- ❌ NUNCA pule validação server-side — zero-trust
- ❌ NUNCA remova aria-* dos primitivos Radix
- ❌ NUNCA misture server state (API data) no Zustand
