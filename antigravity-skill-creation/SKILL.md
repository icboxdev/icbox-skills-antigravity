---
name: Antigravity Skill Creation
description: Generate, validate, and structure skills for the Antigravity AI agent. Ensures progressive disclosure, context management, atomic logic, few-shot prompting, and strict engineering dogmas.
---

# Antigravity Skill Creation — Diretrizes Corporativas Avançadas

## 1. Princípio Zero: A Razão das Skills

As **Skills** não são tutoriais básicos; são pacotes injetáveis de conhecimento ("tribal knowledge") contendo regras inegociáveis. O objetivo é restringir alucinações arquitetônicas e forçar o agente Antigravity a trabalhar exatamente como um **Tech Lead Sênior** na stack específica da equipe.

Se a regra for fofa ou opcional, ela não deve estar em uma skill.

## 2. Progressive Disclosure & YAML Semântico

Para driblar o limite da janela de contexto ("token limit"), o Antigravity lê primeiramente apenas os metadados. O conteúdo do `SKILL.md` só é processado se as palavras-chave baterem com a intenção do usuário.

**Regras do Frontmatter (YAML):**

- **Sempre utilize verbos de ação específicos** no `description` ("Generate", "Validate", "Analyze", "Deploy", "Orchestrate").
- Inclua **todas as tecnologias-chave** suportadas (ex: "React, Server Components, Shadcn").

**Exemplo Obrigatório:**

```yaml
---
name: Next.js App Router Strict Mode
description: Validate, refactor, and generate Next.js code using App Router, React Server Components (RSC), and Server Actions. Imposes strict typing and prohibits client-side fetching where unnecessary.
---
```

## 3. Design Atômico (Single Responsibility)

Nunca crie skills monolíticas ("Faz tudo de Backend e Frontend"). Skills devem ser granulares.

- **Errado**: `AWS + Frontend Web + Database Skill`
- **Certo**: `AWS Lambda Deployment Pipeline` e `Database Schema Migration Protocol`.

O coordenador (Agente) invocará múltiplas skills granulares em paralelo, ativando apensas o que é necessário.

## 4. O Uso de "Few-Shot Prompting"

Um LLM falha ao seguir regras discursivas longas, mas memoriza profundamente quando provido com um exemplo concreto de código.

Toda skill de infraestrutura ou codificação **DEVE fornecer de 2 a 3 snippets curtos de "Copiar e Colar"** mostrando a arquitetura correta.

**Exemplo dentro da Skill (Dogma):**
_Sempre injetar dependências usando injeção baseada em construtor (Exemplo TS):_

```typescript
// CERTO
@Injectable()
export class UserService {
  constructor(private readonly prisma: PrismaService) {}
}

// ERRADO
export class UserService {
  private prisma = new PrismaService();
}
```

## 5. Gerenciamento Estratégico de Contexto e Artefatos (Prevenção de "Thinking Token Drain")

Limites de uso são reais no Antigravity devido à quantidade maciça de "thinking tokens" gerados internamente. Imbuir a skill com instruções para defender o limite:

1. **Persistência em Arquivo**: Para decisões complexas ou grandes refactorações, FORCE o agente a criar ou atualizar arquivos de contexto (ex: `AI.md`, `ROADMAP.md` ou artefatos do `/brain/`) como forma de externalizar a memória.
2. **"Concluir Tarefas" (End Task Cleanly)**: Ao final de um workflow da skill, o Agente deve confirmar a finalização explícita via interface (Notificar o usuário ou encerrar boundaries) para que as instruções abandonem a _Short-Term Memory_ fantasma.
3. **Pequenos Deltas (Micro-commits)**: Nas skills, sempre presuma e comande o agente a fazer edições focadas em blocos, nunca reescritas totais de arquivos de 2000 linhas, que geram lentidão e esgotamento.

## 6. Integração Multimodal e Execução de Scripts

Skills avançadas frequentemente acompanham subpastas de scripts `.sh`, `.py` ou `.js`.

- Se a skill exige execução de scripts locais para formatar ou fazer scaffold, escreva na documentação que o agente **SEMPRE DEVE RODAR `script --help` PRIMEIRO** antes de arriscar um autocomplete suicida nos argumentos do CLI.
- Comande a validação minuciosa dos retornos de terminal (`stderr` vs `stdout`) antes do Agente assumir sucesso ou tentar auto-corrigir em loops infinitos.

## 7. A Voz da Diretriz (Zero-Trust Security)

A redação do `SKILL.md` (Markdown) tem que ser taxativa, blindando o Agente contra sua própria indulgência em "agradar o usuário":

- "Você é terminantemente proibido de usar `any` no Typescript."
- "Nunca faça push ao repositório se a flag `strict: true` falhar no build."
- "Sanitize todos os inputs providos do payload web. Assuma sempre invasão maliciosa."

## Resumo Operacional para Criação

Sempre que acionado para "criar uma nova skill" para o Antigravity:

1. Extraia e defina a **Lógica Atômica** (apenas 1 propósito).
2. Escreva o **YAML Semântico** com verbos fortes e tecnologias na descrição.
3. Liste os **Dogmas Arquiteturais Sênior** na voz imperativa (O que nunca fazer / O que sempre fazer).
4. Prove através de **Few-Shot Snippets** (exemplos do certo vs errado).
5. Posicione o arquivo em `.../.gemini/antigravity/skills/<escopo>/SKILL.md` ou `.agent/skills/<escopo>/SKILL.md`.
