---
name: AI Sales & Revenue Intelligence
description: Architect and generate Sales Intelligence and Revenue Intelligence platforms. Covers reference architecture, data models, AI pipelines (NLP, scoring, forecasting), conversation intelligence, CRM integrations, and implementation best practices.
---

# AI Sales & Revenue Intelligence — Diretrizes Sênior

> **Tipo**: Domain Reference Skill (consultiva). Ativada sob demanda para arquitetura de plataformas de Sales Intelligence.

## 1. Zero-Trust & Limites de Contexto

- **Antes de arquitetar**, externalize o escopo em um artefato — esta skill cobre um domínio amplo.
- Faça **micro-commits**: implemente um módulo/pipeline por vez.
- Para data models completos combinados, consulte `resources/data-models.md`.
- **LGPD/GDPR**: gravação de calls requer consentimento explícito.

## 2. Domínio

**Sales Intelligence**: IA para coletar e entregar insights acionáveis ao time de vendas.
**Revenue Intelligence**: unifica dados de marketing → vendas → CS → expansão para prever e otimizar receita.

| Categoria                 | Referências         | Foco                                |
| ------------------------- | ------------------- | ----------------------------------- |
| Conversation Intelligence | Gong, Chorus        | Análise de calls via NLP            |
| Revenue Orchestration     | Clari, Aviso        | Forecasting, pipeline health        |
| Data & Intent             | ZoomInfo, 6sense    | Enriquecimento + sinais de intenção |
| Sales Engagement          | Salesloft, Outreach | Cadências, automação                |

## 3. Arquitetura de Referência

```
CAMADA DE DADOS (CRM + Email + Calendar + VoIP + External)
         │
    DATA INGESTION (APIs, Webhooks, CDC, Streams)
         │
    DATA PLATFORM (PostgreSQL/ClickHouse + Feature Store)
         │
    AI ENGINE
    ├── Conversation Intelligence (STT + NLP)
    ├── Lead Scoring (ML)
    ├── Deal Health (ML)
    ├── Revenue Forecasting (Stats + ML)
    ├── Lead Enrichment (APIs)
    ├── Activity Capture (Auto-log)
    └── GenAI Copilot (LLM)
         │
    ACTIVATION (Dashboard + Alerts + CRM Writeback + AI Copilot)
```

## 4. Entidades Core

```typescript
interface Account {
  id: string;
  name: string;
  domain: string;
  industry: string;
  employeeCount: number;
  icp_score: number; // Ideal Customer Profile (0-100)
  intent_score: number; // Buying intent (0-100)
}

interface Contact {
  id: string;
  accountId: string;
  firstName: string;
  lastName: string;
  email: string;
  seniority: "C-Level" | "VP" | "Director" | "Manager" | "IC";
  persona: "Decision Maker" | "Champion" | "Influencer" | "User";
  lead_score: number;
  engagement_score: number;
}

interface Deal {
  id: string;
  accountId: string;
  name: string;
  value: number;
  stage:
    | "prospecting"
    | "qualification"
    | "discovery"
    | "proposal"
    | "negotiation"
    | "closed_won"
    | "closed_lost";
  probability: number; // AI-predicted (0-100)
  health_score: number; // AI deal health (0-100)
  risk_factors: string[];
  next_best_action: string | null;
}

interface ConversationAnalysis {
  talkToListenRatio: number; // Rep talk % (ideal: 40-60%)
  topics: { topic: string; sentiment: string }[];
  objections: { text: string; category: string; handled: boolean }[];
  competitorMentions: { competitor: string; context: string }[];
  nextSteps: string[];
  callScore: number; // 0-100 quality
  coachingNotes: string[];
}
```

## 5. AI Pipelines

### Conversation Intelligence

```
Áudio → STT (Whisper/Deepgram) → Diarização → NLP Analysis
  ├── Sentiment (per turn)
  ├── Topic Extraction
  ├── Objection Detection
  ├── Buying Signals
  ├── Competitor Mentions
  ├── Next Steps / Action Items
  └── Call Score + Coaching Notes
```

**Stack**: Whisper (self-hosted) ou Deepgram, pyannote.audio para diarização, GPT-4o/Claude para insights.

### Lead Scoring

Features: demográficas (title, seniority) + firmográficas (industry, revenue) + comportamentais (page views, emails) + intent (keyword search, review sites).
Modelo: Gradient Boost / Random Forest treinado em conversões históricas → Score 0-100.

```typescript
// ✅ CERTO — scoring baseado em múltiplas features ponderadas
function calculateLeadScore(lead: {
  seniority: string;
  industry: string;
  pageViews30d: number;
  emailOpens30d: number;
  intentSignals: number;
}): number {
  let score = 0;
  if (["C-Level", "VP", "Director"].includes(lead.seniority)) score += 25;
  if (lead.pageViews30d > 10) score += 15;
  if (lead.emailOpens30d > 5) score += 15;
  if (lead.intentSignals > 0) score += 25;
  return Math.min(100, score);
}

// ❌ ERRADO — scoring fixo sem dados comportamentais
function leadScore(title: string): number {
  return title.includes("CEO") ? 100 : 20; // Ignora 90% dos sinais
}
```

### Deal Health

```typescript
// ✅ CERTO — scoring baseado em sinais observáveis
function calculateDealHealth(input: {
  recentMeetings: number;
  championActive: boolean;
  nextStepScheduled: boolean;
  daysSinceLastActivity: number;
  closeDatePushed: number;
  ghostedEmails: number;
}): number {
  let score = 50;
  if (input.recentMeetings >= 2) score += 10;
  if (input.championActive) score += 15;
  if (input.nextStepScheduled) score += 10;
  if (input.daysSinceLastActivity > 14) score -= 20;
  if (input.closeDatePushed >= 2) score -= 15;
  if (input.ghostedEmails >= 3) score -= 15;
  return Math.max(0, Math.min(100, score));
}

// ❌ ERRADO — score fixo por stage sem sinais
function dealHealth(stage: string): number {
  return stage === "proposal" ? 60 : 30; // Ignora contexto real
}
```

### Revenue Forecasting

Combinar 4 métodos: Stage-Weighted (20%) + Historical Trends (25%) + AI Predicted (40%) + Rep Commit (15%).

## 6. Stack Recomendada

| Camada   | MVP                   | Scale                |
| -------- | --------------------- | -------------------- |
| Frontend | Next.js / Vue 3       | Next.js              |
| Backend  | NestJS / AdonisJS     | NestJS + Temporal.io |
| Database | PostgreSQL + pgvector | ClickHouse + Qdrant  |
| AI/ML    | OpenAI API, Whisper   | Deepgram, MLflow     |
| Queue    | BullMQ                | Kafka + Flink        |
| Deploy   | Docker + Coolify      | Kubernetes           |

## 7. Boas Práticas

- **Data Quality First**: dedupe + normalização + enrichment ANTES de ML.
- **Start Simple**: regras determinísticas antes de ML (deal health scoring).
- **Human-in-the-Loop**: scores devem ser explicáveis e editáveis.
- **Feedback Loop**: capturar win/loss para retreinar modelos.
- **Guardrails**: limitar alucinações em sugestões de email e coaching.
- **Recording Consent**: aviso obrigatório no início de calls gravadas.
- **RBAC**: reps veem seus deals, managers veem equipe.
- **Encryption at Rest**: transcrições e gravações são dados sensíveis.
