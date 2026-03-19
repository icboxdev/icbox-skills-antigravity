---
name: CRM & Sales Enablement Architecture
description: Architect, generate, and validate CRM and Sales Enablement platforms. Covers data models, pipeline management, workflow automation, RBAC, content library, playbooks, coaching, API design, and multi-tenancy patterns.
---

# CRM & Sales Enablement — Diretrizes Sênior

> **Tipo**: Domain Reference Skill (consultiva). Ativada sob demanda para arquitetura de plataformas CRM.

## 1. Zero-Trust & Limites de Contexto

- **Antes de arquitetar**, externalize o escopo em um artefato — esta skill cobre um domínio amplo.
- Faça **micro-commits**: implemente um módulo (Contacts, Pipeline, Workflow) por vez.
- Para data models completos, consulte `resources/data-models.md`.
- Multi-tenancy: **SEMPRE** filtrar por `tenantId` em TODA query.

## 2. Arquitetura de Referência

```
FRONTEND (SPA)
  Dashboard │ Pipeline (Kanban) │ Contact Detail │ Content Library │ Coaching
         │
API LAYER (REST)
  Auth │ RBAC │ Rate Limit │ Validation │ Versioning
         │
DOMAIN MODULES
  ├── Contacts (Leads, Contacts, Accounts, Segments)
  ├── Pipeline (Deals, Stages, Kanban, Forecast)
  ├── Workflow Engine (Triggers → Conditions → Actions)
  ├── Content Library (Docs, Templates, Battlecards, DSR)
  └── Training (Playbooks, Courses, Quizzes, Coaching)
         │
DATA LAYER
  PostgreSQL │ Redis │ S3/Minio │ BullMQ
         │
INTEGRATIONS
  Email │ Calendar │ Phone │ WhatsApp │ Webhooks │ Zapier
```

## 3. Entidades Core

```typescript
interface Tenant {
  id: string;
  name: string;
  slug: string;
  plan: "free" | "starter" | "pro" | "enterprise";
  settings: {
    timezone: string;
    currency: string;
    dealStages: StageConfig[];
    customFields: CustomField[];
  };
}

interface Lead {
  id: string;
  tenantId: string;
  status: "new" | "contacted" | "qualified" | "unqualified" | "converted";
  source:
    | "website"
    | "referral"
    | "campaign"
    | "cold_outbound"
    | "event"
    | "partner"
    | "organic"
    | "paid";
  firstName: string;
  lastName: string;
  email: string;
  score: number; // 0-100
  assignedTo: string | null;
  customFields: Record<string, unknown>;
}

interface Deal {
  id: string;
  tenantId: string;
  pipelineId: string;
  stageId: string;
  name: string;
  value: number;
  probability: number;
  expectedCloseDate: Date | null;
  ownerId: string;
  accountId: string | null;
  contactIds: string[];
  priority: "low" | "medium" | "high" | "urgent";
  stageEnteredAt: Date; // Track time-in-stage
}

interface Stage {
  id: string;
  pipelineId: string;
  name: string;
  order: number;
  probability: number;
  rottenDays: number | null; // Dias antes de deal ficar "stale"
  requiredFields: string[]; // Campos obrigatórios para mover para este stage
  isWon: boolean;
  isLost: boolean;
}
```

## 4. Pipeline Management

```
Lead (10%) → Qualified (20%) → Discovery (40%) → Proposal (60%) → Negotiation (80%) → Closed Won (100%)
                                                                                     └→ Closed Lost (0%)
```

### Stage Move Validation

```typescript
// ✅ CERTO — validar campos obrigatórios antes de permitir mover
function canMoveToStage(
  deal: Deal,
  targetStage: Stage,
): {
  allowed: boolean;
  missingFields: string[];
} {
  const missing = targetStage.requiredFields.filter(
    (field) => !deal.customFields[field],
  );
  return { allowed: missing.length === 0, missingFields: missing };
}

// ❌ ERRADO — mover deal sem validação
async function moveDeal(dealId: string, stageId: string) {
  await db.deal.update({ where: { id: dealId }, data: { stageId } });
  // Sem validação! Deal pode avançar sem dados críticos
}
```

## 5. Workflow Engine

```typescript
interface Workflow {
  trigger: {
    type:
      | "record_created"
      | "field_changed"
      | "stage_changed"
      | "deal_won"
      | "scheduled";
    entityType: string;
  };
  conditions: {
    field: string;
    operator: "equals" | "gt" | "contains" | "is_empty";
    value: unknown;
  }[];
  actions: {
    type:
      | "send_email"
      | "create_task"
      | "assign_owner"
      | "move_stage"
      | "send_webhook"
      | "send_slack";
    config: Record<string, unknown>;
  }[];
}
```

| Trigger                     | Condição       | Ação                         |
| --------------------------- | -------------- | ---------------------------- |
| Lead criado, source=website | —              | Assign SDR round-robin       |
| Deal → stage `proposal`     | Value > 50k    | Notify manager (Slack)       |
| Deal stale 14 dias          | Stage ≠ closed | Create follow-up task        |
| Deal won                    | —              | Slack celebration 🎉         |
| Lead score > 80             | Status = new   | Auto-convert to contact+deal |

## 6. RBAC

| Role          | Leads    | Contacts        | Deals      | Reports   | Settings |
| ------------- | -------- | --------------- | ---------- | --------- | -------- |
| Admin         | all:\*   | all:\*          | all:\*     | all:view  | all:\*   |
| Sales Manager | team:\*  | team:\*         | team:\*    | team:view | —        |
| AE            | own:\*   | own:\*          | own:\*     | own:view  | —        |
| SDR           | own:\*   | own:create/view | own:create | own:view  | —        |
| Viewer        | all:view | all:view        | all:view   | all:view  | —        |

Scope: `own` (meus registros) | `team` (minha equipe) | `all` (todos).

## 7. API Design

```
Base: /api/v1

GET/POST   /leads              # CRUD paginado
POST       /leads/:id/convert  # Converter em Contact + Deal
GET/POST   /deals              # CRUD
POST       /deals/:id/move     # Mover de stage (com validação!)
POST       /deals/:id/won      # Marcar como ganho
POST       /deals/:id/lost     # Marcar como perdido
GET        /pipelines/:id/deals # Kanban view
```

## 8. Sales Enablement

### Content Library

```typescript
interface ContentItem {
  id: string;
  tenantId: string;
  title: string;
  type:
    | "document"
    | "presentation"
    | "video"
    | "case_study"
    | "battlecard"
    | "proposal_template";
  applicableStages: string[]; // Deal stages onde é útil
  applicablePersonas: string[]; // Buyer personas
  effectiveness: number | null; // Score baseado em correlação com deals ganhos
}
```

### Digital Sales Room (DSR)

```typescript
interface SalesRoom {
  dealId: string;
  slug: string; // URL pública
  contentItems: { contentItemId: string; order: number; isRequired: boolean }[];
  visitors: {
    email: string;
    viewedAt: Date;
    timeSpent: number;
    contentViewed: string[];
  }[];
}
```

### Playbooks

```typescript
interface PlaybookStep {
  order: number;
  title: string;
  type: "email" | "call" | "linkedin" | "task" | "wait";
  delayDays: number | null;
  templateId: string | null; // Link to email template
  tipText: string | null; // Coaching tip
}
```

## 9. Segurança

- **Multi-tenancy**: filtrar `tenantId` em TODA query. Nunca confiar no frontend.

```typescript
// ✅ CERTO — tenantId filtrado em toda query
async function getDeals(tenantId: string, filters: DealFilters) {
  return db.deal.findMany({
    where: {
      tenantId, // SEMPRE presente como primeira condição
      ...buildWhereClause(filters),
    },
  });
}

// ❌ ERRADO — confiar no frontend para filtrar tenant
async function getDeals(filters: DealFilters) {
  return db.deal.findMany({
    where: buildWhereClause(filters), // tenantId vem do body — CROSS-TENANT LEAK
  });
}
```

- **RBAC enforcement**: verificar permissões no middleware, não nos controllers.
- Audit trail: logar quem acessou qual dado quando.
- Sanitizar merge tags em email templates (`{{contact.firstName}}`).
- Rate limiting em APIs públicas e webhooks.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

