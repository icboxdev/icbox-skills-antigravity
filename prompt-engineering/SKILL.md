---
name: Prompt Engineering Sênior
description: Engineer, validate, and optimize prompts for LLMs enforcing structured prompt design, chain-of-thought reasoning, few-shot patterns, anti-hallucination constraints, and output format control. Makes the AI agent proactive, precise, and compliant.
---

# Prompt Engineering — Diretrizes Sênior

## 1. Princípio Zero: Prompts São Código

Prompts não são texto informal — são **instruções de engenharia**. Devem ser tão rigorosos quanto código de produção: estruturados, testáveis, versionáveis, e iteráveis.

- **Todo prompt complexo** deve ser salvo em arquivo (não inline/hardcoded).
- **Itere sempre**: primeiro rascunho nunca é o final. Teste, avalie, refine.
- **Specificity over brevity**: instrução vaga = resultado vago.

## 2. Framework CICE — Estrutura Obrigatória

Todo prompt complexo deve seguir os 4 blocos:

```
C — Contexto:     Quem você é, qual o domínio, background relevante
I — Instrução:    O que fazer, passo a passo, com restrições
C — Constraints:  O que NÃO fazer, limites, proibições
E — Exemplo:      Output esperado (few-shot)
```

### Few-Shot: Prompt Estruturado vs Desorganizado

````markdown
// ✅ CERTO — prompt estruturado com CICE

## Contexto

Você é um engenheiro backend sênior especializado em NestJS e Prisma ORM.
O projeto usa PostgreSQL com RLS e multi-tenancy por `tenantId`.

## Instrução

Crie um service para gerenciar Leads com as operações:

1. `create(dto: CreateLeadDTO)` — validar email único no tenant
2. `findAll(tenantId, filters)` — paginação cursor-based
3. `softDelete(id)` — marcar `deletedAt`, nunca delete físico

## Constraints

- NUNCA use `any` no TypeScript
- SEMPRE filtre por `tenantId` em toda query
- Retorne apenas campos necessários via `select`
- Use transaction interativa para operações multi-tabela

## Exemplo de Output Esperado

```typescript
@Injectable()
export class LeadService {
  constructor(private readonly prisma: PrismaService) {}

  async create(tenantId: string, dto: CreateLeadDTO): Promise<LeadResponse> {
    // ...validação + criação
  }
}
```
````

// ❌ ERRADO — prompt vago sem estrutura
"Cria um service de leads pra mim usando NestJS"
// Resultado: any por todo lado, sem tenant, sem paginação, sem validação

````

## 3. Chain-of-Thought (CoT) — Raciocínio Passo-a-Passo

Use CoT para tarefas que exigem **raciocínio complexo** ou **decisões arquiteturais**.

```markdown
// ✅ CERTO — forçar raciocínio antes de agir
Antes de escrever código, analise passo a passo:

1. Quais entidades estão envolvidas e seus relacionamentos?
2. Quais operações precisam ser transacionais?
3. Quais índices serão necessários para as queries?
4. Quais RLS policies garantem isolamento de dados?
5. Agora, implemente baseado na análise acima.

// ❌ ERRADO — pedir resultado direto sem análise
"Implemente o módulo de pipeline completo com todas as features"
// Resultado: código superficial, sem considerar edge cases
````

## 4. Persona — Role-Based Prompting

```markdown
// ✅ CERTO — persona específica com expertise definida
Você é um Tech Lead com 10 anos de experiência em:

- TypeScript strict (zero `any`)
- NestJS com DI e SOLID
- PostgreSQL com CTEs e window functions
- Segurança Zero-Trust (validar TUDO)

Sua responsabilidade é **revisar** o código proposto e apontar:

1. Violações de SOLID
2. Queries sem índice
3. Inputs não validados
4. Oportunidades de performance

// ❌ ERRADO — sem persona (respostas genéricas)
"Revisa esse código aí"
```

## 5. Output Format Control — Formato Explícito

```markdown
// ✅ CERTO — formato de saída definido
Responda EXATAMENTE neste formato JSON:
{
"analysis": "string — resumo da análise",
"issues": [
{
"severity": "critical | warning | info",
"line": number,
"description": "string",
"suggestion": "string — código corrigido"
}
],
"score": number // 0-100
}

NÃO inclua texto antes ou depois do JSON.
NÃO use markdown code blocks.

// ❌ ERRADO — formato ambíguo
"Me dá uma análise do código"
// Resultado: texto livre sem estrutura, impossível parsear
```

## 6. Anti-Hallucination — Constraints Explícitas

```markdown
// ✅ CERTO — constraints que previnem invenção
REGRAS INEGOCIÁVEIS:

- Se não souber a resposta, diga "Não tenho certeza" — NUNCA invente
- Use APENAS as APIs documentadas neste contexto. Não suponha endpoints
- Se a documentação de referência não cobrir o caso, peça clarificação
- Cite o arquivo fonte de qualquer informação que usar
- Não gere código para bibliotecas que não foram explicitamente listadas

// ❌ ERRADO — sem guardrails (LLM inventa APIs que não existem)
"Integre com a API do sistema usando os endpoints necessários"
// Resultado: endpoints inventados, payloads fantasiosos
```

## 7. Iteração e Decomposição

### 7.1 Task Decomposition — Quebrar em Steps

```markdown
// ✅ CERTO — decomposição explícita em etapas
Implemente o módulo de autenticação seguindo esta ordem:

ETAPA 1: Schema Prisma (model User + model Session)
— Aguarde aprovação antes de prosseguir

ETAPA 2: Auth Service (register, login, logout, refreshToken)
— Aguarde aprovação antes de prosseguir

ETAPA 3: Auth Guard (JWT validation middleware)
— Aguarde aprovação antes de prosseguir

ETAPA 4: Testes unitários do Auth Service

// ❌ ERRADO — tudo de uma vez
"Faz a autenticação completa com registro, login, JWT, refresh token,
guards, testes, e integração com o frontend"
// Resultado: arquivo único monolítico de 500 linhas com bugs
```

### 7.2 Refinamento Iterativo

```markdown
// ✅ CERTO — feedback loop

1. Gere uma primeira versão do componente
2. Eu vou revisar e apontar ajustes
3. Aplique APENAS os ajustes solicitados — não altere o que já está aprovado
4. Repita até aprovação final

// ❌ ERRADO — reescrever tudo a cada feedback
"Refaz o componente inteiro considerando X"
// Resultado: perde customizações anteriores, gasta tokens
```

## 8. System Prompts — Design Patterns

### Template para AI Agents (n8n, Langchain, etc)

```markdown
## Identidade

Você é [PERSONA] especializado em [DOMÍNIO].

## Capacidades

Você tem acesso às seguintes ferramentas:

- [TOOL_1]: descrição precisa do que faz
- [TOOL_2]: descrição precisa do que faz

## Regras

1. Sempre confirmar dados críticos antes de executar ações
2. Nunca executar ações destrutivas sem aprovação explícita
3. Se ambíguo, perguntar ao invés de assumir
4. Responder em pt-BR salvo se solicitado contrário
5. Limitar respostas a [MAX] caracteres quando possível

## Formato de Resposta

- Usar markdown para estruturar
- Citar fontes quando aplicável
- Separar análise de ação
```

## 9. Padrões por Caso de Uso

| Caso de Uso             | Técnica                    | Dica                                 |
| ----------------------- | -------------------------- | ------------------------------------ |
| Geração de código       | Few-shot + Constraints     | Dar exemplo do output esperado       |
| Code review             | Persona + Checklist        | Definir critérios de avaliação       |
| Análise de dados        | CoT + Output format        | Forçar raciocínio antes de conclusão |
| Conversação com usuário | System prompt + Guardrails | Definir limites de escopo            |
| Migração/refactor       | Decomposição + Iteração    | Uma etapa por vez com aprovação      |
| Debug                   | CoT + Contexto amplo       | Incluir logs, stack trace, código    |

## 10. Anti-Patterns

- ❌ **Prompt vago**: "faz isso funcionar" → especificar o comportamento esperado
- ❌ **Tudo de uma vez**: pedir 10 features num prompt → decompor em steps
- ❌ **Sem exemplo**: descrever formato sem mostrá-lo → incluir few-shot
- ❌ **Confiar cegamente**: aceitar primeira resposta → revisar e iterar
- ❌ **Prompt hardcoded**: nunca versionar prompts → salvar em arquivo, usar Git
- ❌ **Ignorar contexto**: não dar background → incluir stack, projeto, domínio
- ❌ **Over-prompting**: prompt de 2000 palavras → conciso, cada palavra conta
