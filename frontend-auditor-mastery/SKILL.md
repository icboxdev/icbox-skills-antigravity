---
name: Frontend Auditor Mastery
description: Audit, standardize, and validate frontend components in React and Vue. Enforces semantic HTML, WCAG 2.1 AA accessibility, strict TypeScript propagation (no 'any'), design system adherence, and component reuse patterns.
---

# Frontend Auditor Mastery — Diretrizes Sênior para Refatoração

## 1. Princípio Zero: Auditoria Impiedosa

Como auditor, seu trabalho é encontrar inconsistências em projetos legados ou em desenvolvimento, eliminar redundâncias (ex: 5 variações do mesmo botão) e forçar o uso correto de tipos e acessibilidade.

## 2. Tipagem Estrita e Fim do `any`

É expressamente **PROIBIDO** ignorar erros de tipo com `as any` ou `@ts-ignore` ao componentizar.

- Ao auditar um arquivo que usa `as any` no React Hook Form, crie imediatamente tipos combinados (`IntersectTypes`) ou faça asserções seguras no `zodResolver`.

```typescript
// CERTO
type UserFormValues = CreateUserSchema & UpdateUserSchema;
const methods = useForm<UserFormValues>({ resolver: zodResolver(schema) });

// ERRADO
const methods = useForm({ resolver: zodResolver(schema) as any });
```

## 3. Acessibilidade Base (WCAG AA)

Sempre que analisar ou gerar componentes, force a validação de a11y:
- **Semântica:** Use `<button>` para ações, `<a>` para navegação. NUNCA `onClick` em `div` ou `span`.
- **Keyboard Navigation:** Tudo o que for clicável DEVE poder receber focus (Tab).
- **ARIA Label:** Se um botão tem apenas um ícone, ele DEVE ter `aria-label` ou texto alternativo visível para leitores de tela (`sr-only`).

```tsx
// CERTO
<button onClick={close} aria-label="Close modal">
  <XIcon className="size-4" />
</button>

// ERRADO
<div onClick={close}>
  <XIcon className="size-4" />
</div>
```

## 4. Padronização do Design System

- Se notar que a aplicação usa Shadcn UI, valide se novos fluxos estão aproveitando componentes existentes (ex: usar `Sheet` para CRUD no lugar de construir um novo Drawer do zero).
- Elimine estilos hardcoded magic numbers (ex: `w-[325px]`, `text-[#ff0000]`). Refatore substituindo por tokens do Tailwind (ex: `w-80`, `text-destructive`).

## 5. Workflow de Execução de Auditoria

1. **Scoping:** Analise layouts base, navigations e forms. Encontrou código duplicado? Fatore em compenente compartilhado.
2. **Type Check:** Procure por `any` usando busca por pattern e remova.
3. **Refatoração:** Ao refatorar, divida grandes monolitos (>200 linhas) em sub-componentes puros.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

