---
name: Software Project Intake & Discovery
description: Extract, classify, and transform non-technical client ideas into structured project specifications ready for MVP development. Covers discovery phases, intake questionnaires, requirement extraction, and LLM-assisted technical translation.
---

# Software Project Intake & Discovery — Diretrizes Sênior

## 1. Princípio Fundamental

> 80% dos clientes são leigos. O processo de intake deve ser **conversacional, visual e progressivo** — nunca um formulário técnico. O objetivo é transformar uma ideia vaga em um Project Brief completo que um desenvolvedor consiga usar para criar o MVP.

## 2. As 5 Fases do Intake

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  1. CONTEXTO │────▶│  2. PROBLEMA │────▶│  3. SOLUÇÃO   │────▶│ 4. PRIORIZAR │────▶│  5. VALIDAR  │
│  Quem é você │     │ O que dói    │     │ O que resolve │     │ MVP vs Nice  │     │ Confirma?    │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
```

### Fase 1 — CONTEXTO (Quem é o cliente)

Extrair **sem parecer entrevista**:

- Segmento/ramo de atuação
- Porte da empresa (sozinho, equipe pequena, empresa)
- Como opera hoje (papel, planilha, WhatsApp, sistema antigo)
- Quem são os usuários finais

**Perguntas-chave (linguagem leiga):**

- "Me conta um pouco sobre o que você faz"
- "Quantas pessoas trabalham com você?"
- "Como vocês controlam as coisas hoje?"

### Fase 2 — PROBLEMA (Dor principal)

Usar técnica dos **5 Porquês** para encontrar a causa raiz:

- Qual a maior dificuldade no dia-a-dia?
- O que consome mais tempo?
- O que dá mais dor de cabeça?
- Quanto custa (tempo/dinheiro) esse problema?

**Perguntas-chave:**

- "O que mais atrapalha no dia-a-dia?"
- "Se pudesse mudar UMA coisa, o que seria?"
- "Quanto tempo você perde com isso por semana?"

### Fase 3 — SOLUÇÃO (O que o sistema deve fazer)

Traduzir a dor em funcionalidades concretas:

- Mapear jornadas do usuário principal
- Identificar as 3-5 funcionalidades essenciais (Must-have)
- Separar Nice-to-have claramente
- Identificar integrações necessárias (WhatsApp, pagamento, etc.)

**Perguntas-chave:**

- "Imagina que o sistema está pronto. O que você faz primeiro ao abrir?"
- "Quem mais precisa acessar? O que cada pessoa faria?"
- "Precisa funcionar no celular?"
- "Precisa de relatórios? De que tipo?"

### Fase 4 — PRIORIZAR (MVP vs Futuro)

Método MoSCoW adaptado para leigos:

- **Precisa ter** (Must) — sem isso o sistema não serve
- **Seria bom** (Should) — agrega valor, v2
- **Se der** (Could) — legal, mas não essencial
- **Depois** (Won't) — próxima versão

### Fase 5 — VALIDAR (Resumo e confirmação)

Apresentar resumo em linguagem do cliente:

- Reapresentar o problema na voz do cliente
- Listar funcionalidades com descrição leiga
- Confirmar público e dispositivos
- Só depois gerar a especificação técnica

## 3. Dados a Extrair (Minimum Viable Spec)

Todo intake DEVE resultar em:

```typescript
interface ProjectBrief {
  // Identificação
  name: string; // Nome criativo (2-3 palavras)
  slug: string; // URL-friendly
  description: string; // 2-3 frases para leigo

  // Contexto do cliente
  clientProfile: {
    segment: string; // Ex: "Oficina mecânica"
    companySize: string; // Ex: "5 funcionários"
    currentTools: string; // Ex: "Papel e WhatsApp"
    painLevel: "low" | "medium" | "high" | "critical";
  };

  // Problema
  problem: {
    summary: string; // Resumo da dor
    impact: string; // Impacto no negócio
    frequency: string; // Com que frequência ocorre
  };

  // Solução
  targetUsers: {
    primary: string; // Usuário principal
    secondary?: string; // Usuários secundários
    estimatedCount: string;
    devices: string[]; // ['mobile', 'desktop']
  };

  // Funcionalidades classificadas
  modules: Array<{
    name: string;
    description: string; // Descrição leiga
    technicalSpec: string; // Tradução técnica (LLM)
    priority: "must" | "should" | "could" | "wont";
  }>;

  // Técnico (gerado pelo LLM)
  technicalBrief: {
    suggestedStack: string;
    architecture: string; // Ex: "SPA + REST API"
    integrations: string[]; // Ex: ["WhatsApp", "PIX"]
    estimatedComplexity: "simple" | "medium" | "complex";
    estimatedSprints: number;
  };
}
```

## 4. Tradução Leigo → Técnico (via LLM)

O LLM deve traduzir informação do cliente em especificação técnica:

```
// ✅ CERTO — Tradução contextual
Cliente: "Quero que quando o carro fica pronto, avise o dono"
→ Módulo: "Notificações"
→ Spec: "Push notification e/ou WhatsApp trigger quando status
   do serviço muda para 'concluído'. Requer: event-driven
   architecture, integração WhatsApp API."

// ❌ ERRADO — Tradução literal
Cliente: "Quero que avise"
→ Spec: "Implementar sistema de avisos" // vago demais
```

### Prompt de Tradução Técnica

Ao converter o resumo do cliente para ProjectBrief, usar este contexto:

1. Traduzir cada funcionalidade em módulo técnico com entidades, endpoints e UI necessária
2. Inferir stack baseado na complexidade (simples = SPA, média = SPA+API, complexa = microservices)
3. Estimar sprints (1 sprint = 2 semanas): simples 2-3, médio 4-6, complexo 8+
4. Listar integrações necessárias baseado no contexto (pagamento, notificações, etc.)

## 5. Interface do Wizard — Dogmas

### Para o cliente (leigo):

- **Zero jargão técnico** — "módulo" vira "funcionalidade", "endpoint" vira "tela"
- **Perguntas visuais** — cards clicáveis, não campos texto
- **Máximo 6 steps** — se precisar de mais, está errado
- **Progresso visual** — stepper com % ou barra
- **Exemplos em cada campo** — placeholder realista, não "Lorem ipsum"
- **Ajuda contextual** — tooltips explicando por que cada info importa

### Steps recomendados:

1. **Sobre Você** — Ramo, porte, como opera hoje (cards visuais)
2. **Seu Desafio** — Problema principal, impacto, frequência (textarea + opções)
3. **Sua Solução** — O que imagina, quem usa, dispositivos (cards + checkboxes)
4. **Funcionalidades** — LLM sugere baseado no input, cliente confirma/edita
5. **Prioridades** — Drag & drop ou categorização visual (Must/Should/Could)
6. **Revisão** — Resumo completo em linguagem do cliente, botão criar

## 6. Anti-Patterns

- ❌ Pedir ao leigo para escolher stack ou arquitetura
- ❌ Usar termos como "CRUD", "REST", "microserviço" na interface
- ❌ Formulário com mais de 3 campos por step
- ❌ Perguntar tudo de uma vez — progressive disclosure
- ❌ Não validar com o cliente antes de gerar spec técnica
- ❌ Gerar spec genérica que serve para qualquer projeto
- ❌ Permitir módulos sem descrição concreta

## 7. O Papel do LLM no Processo

O LLM atua em 3 momentos:

1. **Sugestão de Funcionalidades** — Baseado no problema do cliente, o LLM sugere módulos relevantes que o cliente pode confirmar ou remover
2. **Tradução Técnica** — Converte a linguagem do cliente em spec para o dev
3. **Estimativa** — Sugere complexidade, stack e timeline baseado nos módulos

## 8. Métricas de Qualidade do Intake

Um bom intake deve resultar em:

- [ ] Nome do projeto definido
- [ ] Problema claramente articulado
- [ ] Pelo menos 3 módulos Must-have com descrição
- [ ] Público-alvo identificado
- [ ] Dispositivos definidos (mobile/desktop)
- [ ] Estimativa de complexidade gerada
- [ ] Cliente confirmou o resumo
