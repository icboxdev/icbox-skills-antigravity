# 🚀 Antigravity Skills

Coleção de **25 Skills** para o agente AI **Antigravity** — pacotes injetáveis de conhecimento ("tribal knowledge") contendo regras inegociáveis para engenharia de software sênior.

## O que são Skills?

Skills são documentos `.md` que restringem alucinações arquitetônicas e forçam o agente a trabalhar como um **Tech Lead Sênior** na stack específica. Cada skill contém:

- **YAML Semântico** — verbos de ação + tecnologias na descrição
- **Dogmas Arquiteturais** — regras inegociáveis ("O que nunca fazer / sempre fazer")
- **Few-Shot Snippets** — exemplos `CERTO` vs `ERRADO` para memorização do LLM
- **Zero-Trust Voice** — voz imperativa, validação de inputs, segurança

## Skills Disponíveis

### Meta

| Skill                        | Descrição                    |
| ---------------------------- | ---------------------------- |
| `antigravity-skill-creation` | Guia para criar novas skills |

### Backend

| Skill              | Descrição                                              |
| ------------------ | ------------------------------------------------------ |
| `node-strict`      | NestJS / Fastify com DI, strict typing, error handling |
| `fastapi-pydantic` | FastAPI + Pydantic v2 strict, async-first              |
| `laravel-inertia`  | Laravel + Inertia.js, skinny controllers               |

### Frontend

| Skill               | Descrição                               |
| ------------------- | --------------------------------------- |
| `vue-primevue`      | Vue 3 + PrimeVue Unstyled + Tailwind    |
| `react-shadcn`      | React + Shadcn UI + Radix + Tailwind    |
| `nextjs-app-router` | Next.js App Router, RSC, Server Actions |

### Mobile / Desktop

| Skill              | Descrição                             |
| ------------------ | ------------------------------------- |
| `flutter-riverpod` | Flutter + Riverpod, Sound Null Safety |
| `tauri-frontend`   | Tauri IPC security, Rust commands     |

### Data Layer

| Skill              | Descrição                                    |
| ------------------ | -------------------------------------------- |
| `prisma-orm`       | Schema, migrations, queries, transactions    |
| `supabase-backend` | Auth, RLS, Storage, Edge Functions, Realtime |
| `postgresql-sql`   | Índices, CTEs, window functions, EXPLAIN     |

### Infraestrutura

| Skill            | Descrição                                             |
| ---------------- | ----------------------------------------------------- |
| `docker-compose` | Multi-stage builds, healthchecks, secrets             |
| `coolify-deploy` | Deploy automation via Coolify REST API                |
| `git-cicd`       | Trunk-based dev, conventional commits, GitHub Actions |

### Cross-Stack

| Skill                 | Descrição                                |
| --------------------- | ---------------------------------------- |
| `typescript-patterns` | Branded types, guards, satisfies, unions |
| `testing-vitest`      | Vitest/Playwright, AAA, factories, E2E   |
| `ui-animations`       | GPU-accelerated animations, motion a11y  |
| `a11y-wcag`           | WCAG 2.2 AA, keyboard, ARIA, contrast    |

### Design System

| Skill                 | Descrição                              |
| --------------------- | -------------------------------------- |
| `supabase-design-vue` | Dark-first Supabase-inspired UI tokens |

### Integrações

| Skill                 | Descrição                             |
| --------------------- | ------------------------------------- |
| `whatsapp-cloud-api`  | Meta WhatsApp Business API oficial    |
| `whatsapp-unofficial` | Evolution API + Baileys               |
| `gowa-whatsapp`       | GOWA REST API (Go, MCP, HMAC)         |
| `n8n-automation`      | Workflows, Code Nodes, MCP, AI Agents |

### Domain Knowledge

| Skill                   | Descrição                            |
| ----------------------- | ------------------------------------ |
| `ai-sales-intelligence` | Sales/Revenue Intelligence platforms |
| `crm-sales-enablement`  | CRM, pipeline, RBAC, enablement      |

## Como Usar

1. Coloque esta pasta em `~/.gemini/antigravity/skills/` ou `.agent/skills/`
2. O agente Antigravity carrega automaticamente as skills por match de keywords
3. Para criar novas skills, consulte `antigravity-skill-creation/SKILL.md`

## Licença

MIT — use, modifique e compartilhe livremente.
