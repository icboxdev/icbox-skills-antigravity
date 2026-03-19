---
name: React Hook Form + Zod Patterns
description: Validate, generate, and optimize React Hook Form v7 with Zod resolver patterns. Enforces typed schemas, conditional fields, useFieldArray, drawer-based CRUD forms, controlled components, and zero-trust client+server validation.
---

# React Hook Form + Zod — Patterns de Formulário Produtivos

## 1. Propósito

Padronizar a criação de formulários em React com React Hook Form + Zod, eliminando boilerplate, garantindo type-safety total e forçando validação dual (client + server). Cobre desde forms simples até drawers CRUD com campos condicionais e arrays dinâmicos.

## 2. Dogmas Arquiteturais

### Schema-First

**SEMPRE** definir o schema Zod ANTES do componente. O schema é a single source of truth para tipos, validações e defaults.

### Resolver Obrigatório

**NUNCA** usar `register` com validação inline. **SEMPRE** usar `zodResolver` para centralizar validação no schema.

### Tipagem Automática

**NUNCA** definir manualmente o tipo do form. Use `z.infer<typeof schema>` para derivar automaticamente.

### Validação Dual

**NUNCA** confiar apenas na validação client-side. O servidor DEVE revalidar com o mesmo schema (ou equivalente).

## 3. Patterns Essenciais

### 3.1 Form Básico com Zod

```typescript
// CERTO — Schema-first, tipagem automática
import { z } from "zod";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";

const userSchema = z.object({
  name: z.string().min(2, "Mínimo 2 caracteres"),
  email: z.string().email("E-mail inválido"),
  role: z.enum(["admin", "member", "viewer"]),
});

type UserForm = z.infer<typeof userSchema>;

function UserFormDrawer({ onSubmit }: { onSubmit: (data: UserForm) => void }) {
  const form = useForm<UserForm>({
    resolver: zodResolver(userSchema),
    defaultValues: { name: "", email: "", role: "member" },
  });

  return (
    <form onSubmit={form.handleSubmit(onSubmit)}>
      <Input {...form.register("name")} />
      {form.formState.errors.name && (
        <p className="text-sm text-destructive">{form.formState.errors.name.message}</p>
      )}
    </form>
  );
}
```

```typescript
// ERRADO — Validação inline, tipo manual, sem resolver
type UserForm = { name: string; email: string };  // duplicado!

const form = useForm<UserForm>();

<input {...form.register("name", { required: "Obrigatório", minLength: 2 })} />
```

### 3.2 Campos Condicionais com `watch`

```typescript
// CERTO — Campo aparece/desaparece baseado em outro valor
const schema = z.discriminatedUnion("type", [
  z.object({ type: z.literal("smtp"), host: z.string().min(1), port: z.coerce.number() }),
  z.object({ type: z.literal("resend"), apiKey: z.string().min(1) }),
]);

type EmailConfig = z.infer<typeof schema>;

function EmailForm() {
  const form = useForm<EmailConfig>({
    resolver: zodResolver(schema),
    defaultValues: { type: "smtp", host: "", port: 587 },
  });

  const emailType = form.watch("type");

  return (
    <form>
      <Select onValueChange={(v) => form.setValue("type", v as EmailConfig["type"])}>
        ...
      </Select>
      {emailType === "smtp" && (
        <>
          <Input {...form.register("host")} />
          <Input {...form.register("port")} type="number" />
        </>
      )}
      {emailType === "resend" && (
        <Input {...form.register("apiKey")} />
      )}
    </form>
  );
}
```

```typescript
// ERRADO — Campos condicionais sem discriminated union
const schema = z.object({
  type: z.string(),
  host: z.string().optional(),  // Quando type=smtp, host é obrigatório!
  apiKey: z.string().optional(),
});
// Problema: não valida que host é obrigatório quando type=smtp
```

### 3.3 useFieldArray para Listas Dinâmicas

```typescript
// CERTO — Array de permissões editável
const groupSchema = z.object({
  name: z.string().min(1),
  permissions: z.array(z.object({
    resource: z.string().min(1),
    action: z.enum(["read", "write", "delete"]),
  })).min(1, "Ao menos 1 permissão"),
});

function GroupForm() {
  const form = useForm<z.infer<typeof groupSchema>>({
    resolver: zodResolver(groupSchema),
    defaultValues: { name: "", permissions: [{ resource: "", action: "read" }] },
  });

  const { fields, append, remove } = useFieldArray({
    control: form.control,
    name: "permissions",
  });

  return (
    <form>
      {fields.map((field, index) => (
        <div key={field.id}>
          <Input {...form.register(`permissions.${index}.resource`)} />
          <Button variant="ghost" onClick={() => remove(index)}>✕</Button>
        </div>
      ))}
      <Button type="button" onClick={() => append({ resource: "", action: "read" })}>
        Adicionar
      </Button>
    </form>
  );
}
```

### 3.4 Drawer CRUD Pattern

```typescript
// CERTO — Form dentro de CrudDrawer, reset ao abrir/editar
function ItemFormDrawer({ open, onOpenChange, item, onSubmit }: Props) {
  const form = useForm<ItemForm>({
    resolver: zodResolver(itemSchema),
    defaultValues: { name: "", description: "" },
  });

  // Reset form quando item muda (criar vs editar)
  useEffect(() => {
    if (open) {
      form.reset(item ? { name: item.name, description: item.description } : { name: "", description: "" });
    }
  }, [open, item, form]);

  return (
    <CrudDrawer
      open={open}
      onOpenChange={onOpenChange}
      title={item ? "Editar Item" : "Novo Item"}
      onSubmit={form.handleSubmit(onSubmit)}
      isSubmitting={form.formState.isSubmitting}
    >
      <Input {...form.register("name")} />
      {form.formState.errors.name && (
        <p className="text-sm text-destructive">{form.formState.errors.name.message}</p>
      )}
    </CrudDrawer>
  );
}
```

```typescript
// ERRADO — Reset manual, sem useEffect, form stale ao reabrir
function ItemFormDrawer({ open, item }: Props) {
  const [name, setName] = useState("");  // Estado manual = bug-prone
  // Item muda mas form não reseta
}
```

### 3.5 Select Controlado com shadcn

```typescript
// CERTO — Select do shadcn com Controller do RHF
import { Controller } from "react-hook-form";

<Controller
  control={form.control}
  name="role"
  render={({ field }) => (
    <Select value={field.value} onValueChange={field.onChange}>
      <SelectTrigger>
        <SelectValue placeholder="Selecione..." />
      </SelectTrigger>
      <SelectContent>
        <SelectItem value="admin">Admin</SelectItem>
        <SelectItem value="member">Membro</SelectItem>
      </SelectContent>
    </Select>
  )}
/>
```

```typescript
// ERRADO — Select sem Controller, onChange manual
<Select onValueChange={(v) => form.setValue("role", v)}>
  {/* Funciona mas perde form.formState.isDirty tracking */}
</Select>
```

## 4. Performance

- **SEMPRE** usar `mode: "onBlur"` ou `mode: "onChange"` seletivamente. Default `onSubmit` é o mais performático.
- **NUNCA** colocar `watch()` no top-level sem necessidade — causa re-render a cada keystroke.
- **Preferir** `useWatch` hook para observar campos específicos sem re-render do form inteiro.
- **Usar** `shouldUnregister: true` para campos condicionais que desaparecem do DOM.

## 5. Zod Patterns Avançados

```typescript
// Preprocess para coerção automática
const schema = z.object({
  port: z.coerce.number().int().min(1).max(65535),
  active: z.coerce.boolean(),
  tags: z.preprocess(
    (val) => (typeof val === "string" ? val.split(",").map((s) => s.trim()) : val),
    z.array(z.string())
  ),
});

// Refine para validação cross-field
const dateRange = z.object({
  startDate: z.string(),
  endDate: z.string(),
}).refine((data) => data.endDate >= data.startDate, {
  message: "Data fim deve ser após data início",
  path: ["endDate"],
});
```

## 6. Zero-Trust

- **NUNCA** confiar apenas em validação client-side com Zod — o servidor DEVE revalidar.
- **NUNCA** usar `any` em tipos de form — derivar tudo de `z.infer<typeof schema>`.
- **NUNCA** fazer `form.setValue` sem `{ shouldValidate: true }` quando o valor vem de fonte externa.
- **SEMPRE** mostrar erros inline abaixo do campo, nunca apenas em toast.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

