---
name: shadcn/ui Internals & Composition
description: Validate, customize, and compose shadcn/ui components understanding Radix primitives, asChild pattern, cva variants, cn() utility, CSS custom properties, and design system architecture.
---

# shadcn/ui Internals — Radix, cva, Composition & Customização

## 1. Propósito

Entender a arquitetura interna do shadcn/ui para customizar, estender e compor componentes sem quebrar acessibilidade, sem duplicar código e sem lutar contra o framework. O agente deve saber QUANDO usar asChild, COMO criar variantes com cva, e COMO compor components do design system.

## 2. Dogmas Arquiteturais

### shadcn ≠ Biblioteca

shadcn/ui é um **sistema de distribuição de código**, não uma dependência. Os componentes ficam no SEU código (`components/ui/`). Você tem ownership total. Edite-os diretamente.

### Composição sobre Herança

**SEMPRE** compor componentes existentes para criar novos. NUNCA criar componentes do zero quando um shadcn existe que pode ser estendido.

### cn() é Obrigatório

**NUNCA** concatenar classes com template literals. **SEMPRE** usar `cn()` (clsx + twMerge) para merge inteligente de classes Tailwind.

### Radix é a Base

Entender que shadcn/ui = Radix primitives + Tailwind styling. Se o comportamento precisa mudar, consulte os docs do Radix, não do shadcn.

## 3. Arquitetura

```
┌─────────────────────────────────────────┐
│              Sua Aplicação              │
├─────────────────────────────────────────┤
│   Pages (composição de templates)       │
├─────────────────────────────────────────┤
│   Templates (PageHeader, CrudDrawer)    │  ← Seus componentes compartilhados
├─────────────────────────────────────────┤
│   shadcn/ui (Button, Dialog, Table)     │  ← components/ui/ — seu código
├─────────────────────────────────────────┤
│   Radix Primitives (Dialog, Popover)    │  ← node_modules — não editar
├─────────────────────────────────────────┤
│   React DOM                             │
└─────────────────────────────────────────┘
```

## 4. Patterns Essenciais

### 4.1 cn() — Merge Inteligente de Classes

```typescript
// CERTO — cn() resolve conflitos automaticamente
import { cn } from "@/lib/utils";

function Card({ className, ...props }: React.ComponentProps<"div">) {
  return (
    <div
      className={cn(
        "rounded-lg border bg-card text-card-foreground shadow-sm",  // defaults
        className  // override do consumidor
      )}
      {...props}
    />
  );
}

// Usar: <Card className="border-primary" /> → border-primary substitui border
```

```typescript
// ERRADO — Template literal não resolve conflitos Tailwind
function Card({ className }: { className?: string }) {
  return (
    <div className={`rounded-lg border bg-card ${className}`}>
      {/* "border" e "border-primary" coexistem = bug visual */}
    </div>
  );
}
```

### 4.2 cva — Class Variance Authority

```typescript
// CERTO — Variantes tipadas com cva
import { cva, type VariantProps } from "class-variance-authority";

const badgeVariants = cva(
  "inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-semibold transition-colors",
  {
    variants: {
      variant: {
        default: "border-transparent bg-primary text-primary-foreground",
        secondary: "border-transparent bg-secondary text-secondary-foreground",
        destructive: "border-transparent bg-destructive text-destructive-foreground",
        outline: "text-foreground",
      },
    },
    defaultVariants: {
      variant: "default",
    },
  }
);

interface BadgeProps
  extends React.HTMLAttributes<HTMLDivElement>,
    VariantProps<typeof badgeVariants> {}

function Badge({ className, variant, ...props }: BadgeProps) {
  return <div className={cn(badgeVariants({ variant }), className)} {...props} />;
}
```

```typescript
// ERRADO — Variantes com ifs manuais
function Badge({ variant }: { variant: "default" | "outline" }) {
  return (
    <div className={
      variant === "default" ? "bg-primary text-white" :
      variant === "outline" ? "border text-foreground" : ""
    }>
      {/* Não extensível, não type-safe, não merge-safe */}
    </div>
  );
}
```

### 4.3 asChild — Composição sem DOM extra

```typescript
// CERTO — asChild delega renderização para o filho
import { Slot } from "@radix-ui/react-slot";

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  asChild?: boolean;
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ asChild = false, className, ...props }, ref) => {
    const Comp = asChild ? Slot : "button";
    return <Comp className={cn(buttonVariants(), className)} ref={ref} {...props} />;
  }
);

// Uso: Botão que é um link
<Button asChild>
  <Link href="/settings">Configurações</Link>   {/* Renderiza <a>, não <button><a> */}
</Button>
```

```typescript
// ERRADO — Wrapper desnecessário, DOM extra
<Button>
  <a href="/settings">Configurações</a>   {/* Renderiza <button><a> = inacessível */}
</Button>
```

### 4.4 Composição de Componentes Compartilhados

```typescript
// CERTO — Compor shadcn para criar componentes do projeto
import { Sheet, SheetContent, SheetHeader, SheetTitle, SheetDescription } from "@/components/ui/sheet";
import { Button } from "@/components/ui/button";

interface CrudDrawerProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  description?: string;
  onSubmit?: () => void;
  isSubmitting?: boolean;
  children: React.ReactNode;
}

export function CrudDrawer({ open, onOpenChange, title, description, onSubmit, isSubmitting, children }: CrudDrawerProps) {
  const content = (
    <>
      <SheetHeader>
        <SheetTitle>{title}</SheetTitle>
        {description && <SheetDescription>{description}</SheetDescription>}
      </SheetHeader>
      <div className="flex-1 overflow-y-auto px-6 py-4">
        {children}
      </div>
      {onSubmit && (
        <div className="border-t px-6 py-4 flex justify-end gap-2">
          <Button variant="outline" onClick={() => onOpenChange(false)}>Cancelar</Button>
          <Button type="submit" disabled={isSubmitting}>Salvar</Button>
        </div>
      )}
    </>
  );

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent className="flex flex-col">
        {onSubmit ? <form onSubmit={onSubmit} className="flex flex-col flex-1">{content}</form> : content}
      </SheetContent>
    </Sheet>
  );
}
```

```typescript
// ERRADO — Criar drawer custom do zero ignorando Sheet do shadcn
function CustomDrawer({ open }: { open: boolean }) {
  return open ? (
    <div className="fixed right-0 top-0 h-full w-96 bg-white shadow-xl z-50">
      {/* Sem animação, sem overlay, sem a11y, sem focus trap */}
    </div>
  ) : null;
}
```

### 4.5 CSS Custom Properties (Design Tokens)

```css
/* CERTO — Tokens semânticos via CSS variables */
@layer base {
  :root {
    --background: 0 0% 100%;
    --foreground: 240 10% 3.9%;
    --primary: 240 5.9% 10%;
    --primary-foreground: 0 0% 98%;
    /* Usar formato HSL sem função para composição com opacity */
  }

  .dark {
    --background: 240 10% 3.9%;
    --foreground: 0 0% 98%;
    --primary: 0 0% 98%;
    --primary-foreground: 240 5.9% 10%;
  }
}
```

```css
/* ERRADO — Cores hardcoded, sem tokens */
.card { background: #111113; }  /* Não muda com theme switch */
.button { background: #38bdf8; }  /* Duplicado em N lugares */
```

## 5. Radix Primitives — O que Saber

| Conceito | Descrição |
|----------|-----------|
| **Uncontrolled** | Props `defaultOpen`, `defaultValue` — Radix gerencia estado |
| **Controlled** | Props `open`, `onOpenChange` — você gerencia estado |
| **Compound** | Dialog.Root > Dialog.Trigger > Dialog.Content — composição obrigatória |
| **Portal** | Conteúdo renderiza fora do DOM tree (evita z-index issues) |
| **Focus Trap** | Dialog e Popover trancam foco dentro quando abertos |
| **Dismiss** | Click outside e Escape fecham automaticamente |

## 6. Regras de Customização

1. **Estilo** → Editar diretamente em `components/ui/*.tsx` via `cn()` e `cva`
2. **Comportamento** → Consultar docs Radix para props disponíveis
3. **Composição** → Criar componentes em `components/` que compõem os de `components/ui/`
4. **Novo componente** → Primeiro verificar se shadcn já tem. Depois verificar Radix. Só então criar custom.

## 7. Zero-Trust

- **NUNCA** instalar shadcn/ui como dependência npm — componentes ficam no código.
- **NUNCA** editar `node_modules/@radix-ui/*` — customizar via shadcn wrappers.
- **NUNCA** usar `!important` para sobrescrever estilos shadcn — usar `cn()` corretamente.
- **NUNCA** criar componentes inline (modais, alerts) quando shadcn já oferece equivalente.
- **SEMPRE** propagar `className` via `cn()` em componentes custom para permitir override.
- **SEMPRE** usar `forwardRef` em componentes que wrappam Radix primitives.
