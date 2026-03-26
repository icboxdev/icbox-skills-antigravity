---
name: Antigravity MCP Core Development
description: Architect, generate, and govern the addition of new tools to the Antigravity MCP Core. Enforces TypeScript dogmas, StdioServerTransport usage, deterministic local execution, and structural tool registration over shell script execution.
---

# Antigravity MCP Core Development

## 1. O Que é Esta Skill? (Propósito)
Esta skill rege como os agentes de IA devem criar e adicionar novas ferramentas (tools) ao **Antigravity MCP Core**, um servidor MCP local focado em substituir a necessidade de scripts bash interativos por execuções determinísticas via protocolo MCP. O objetivo é estabelecer o padrão SSJ3 de processamento local, determinístico e de baixíssima latência para introspecção e manipulação do ambiente do usuário.

## 2. Quando Usar Esta Skill? (Contexto de Ativação)
- Quando for requisitada uma nova "ability" de longa execução ou introspecção profunda (ler AST, gerenciar containers, schemas DB).
- Quando for preciso executar análises no banco de dados, Docker ou Git de forma programática.
- Sempre que houver a tentação de criar um script python/bash longo para parsear saídas de terminal complexas, crie uma ferramenta MCP estruturada ao invés disso.
- Para orientar a evolução do projeto `/home/ideilson/.gemini/antigravity/scratch/work/antigravity-mcp-core`.

## 3. Dogmas de Engenharia (Strict Rules)

- **TypeScript First**: O core é puramente Node.js/TypeScript para máxima velocidade de inicialização e fácil manutenção.
- **StdioServerTransport**: Toda a comunicação é feita via `stdio`. Evite HTTP/SSE a menos que expressamente solicitado, para manter a simplicidade do ciclo de vida atrelado ao client MCP.
- **Isolamento de Tools**: Cada tool DEVE ocupar seu próprio arquivo dentro de `src/tools/`. NUNCA inflar o arquivo raiz de servidor (`index.ts`) com a lógica interna das ferramentas.
- **Retornos Estruturados (JSON)**: Os retornos das tools DEVEM ser estruturados com um payload text contendo um JSON limpo (usualmente via `JSON.stringify`), retornando arrays ou objetos fáceis do LLM injerir e interpretar (`content: [{ type: "text", text: ... }]`).
- **Uso de APIs Nativas**: Não crie wrappers desnecessários para comandos bash vulgares se a API existir nativamente no Node.js (ex: `fs/promises`). O objetivo das ferramentas MCP é a introspecção profunda estruturada (ex: AST) ao invés de regex sobre `grep`.

## 4. Onde a Lógica Vive? (Estrutura do MCP Core)
O MCP Core habita em `/home/ideilson/.gemini/antigravity/scratch/work/antigravity-mcp-core`.
A estrutura obedece:
```
src/
  index.ts            # Registro do Transport, Rotas de Tools e Mapeamento
  tools/
    meu_novo_tool.ts  # Implementação atômica
```

## 5. Como Adicionar Uma Nova Tool (Passo a Passo)

1. **Crie o Arquivo da Tool**: Ex: `src/tools/parse_ast.ts`.
2. **Defina a Exportação da Interface (`Tool`)**:
   Exporte uma definição constante do SDK contendo `name`, `description` e `inputSchema`.
3. **Crie o Handler**:
   Crie a função de negócio assíncrona recebendo `Record<string, unknown>` mapeando os inputs. Ela retorna um `CallToolResult`.
4. **Altere o `index.ts`**:
   Importe a definição e o handler no `index.ts`, e registre em `ListToolsRequestSchema` e `CallToolRequestSchema`.
5. **Recompile o Core**:
   Execute `npm run build` na raiz do MCP Core para compilar todo o código e garantir tipagem estrita no `tsc`.

## 6. Zero-Trust & Segurança
- NUNCA crie tools sem validação de schemas de input. Use tipos primitivos rígidos no `inputSchema`.
- Em operações no sistema de arquivos, evite diretórios abertos. Limite razoavelmente se estiver manipulando modificações destrutivas.
- Para processamento que depende de bibliotecas externas cruas, faça sanitização (evite `exec` string injection).

## 7. Exemplos (Few-Shot Prompting)

### ERRADO ❌ (Script Poluído, Não estruturado)
```typescript
// src/tools/list.ts
import { execSync } from 'child_process';
export function listFiles(dir: string) {
  // Errado: Command injection possível. Fere o isolamento.
  return execSync(`ls -la ${dir}`).toString();
}
```

### CERTO ✅ (Isolado, Tipado, Retorno Estruturado)
```typescript
// src/tools/project_inspector.ts
import fs from 'fs/promises';
import { Tool } from '@modelcontextprotocol/sdk/types.js';

export const projectInspectorTool: Tool = {
  name: "project_inspector",
  description: "Inspects a project directory.",
  inputSchema: {
    type: "object",
    properties: { directory: { type: "string" } },
    required: ["directory"]
  }
};

export async function handleProjectInspector(args: Record<string, unknown>) {
  const dir = String(args.directory);
  // Logica...
  const result = { success: true, files: ["a.ts"] };
  return {
    content: [{ type: "text", text: JSON.stringify(result, null, 2) }]
  };
}
```

## 8. Catálogo AIOps Maestro Tools (v2.0.0 — 50 tools: AIOps + Infra + Realtime)

O MCP Core expõe **50 tools** em 6 domínios.
Use este catálogo para saber QUAL tool usar em cada situação.

### Projetos
| Tool | Quando usar |
|---|---|
| `aiops_create_project` | Iniciar novo projeto (idempotente por nome) |
| `aiops_list_projects` | Verificar projetos antes de criar um novo |
| `aiops_get_project` | Estado atual + stages + progresso pelo ID |
| `aiops_update_project` | Mudar status: ACTIVE → IN_PROGRESS → COMPLETED |
| `aiops_get_project_activity` | Revisar histórico de ações antes de continuar |
| `aiops_get_project_metrics` | Health check geral do Maestro |

### Stages
| Tool | Quando usar |
|---|---|
| `aiops_create_stage` | Criar etapa dentro de um projeto |
| `aiops_get_stage` | Verificar status de uma stage pelo ID |
| `aiops_update_stage` | Mover para IN_PROGRESS, corrigir campos |
| `aiops_complete_stage` | ⭐ Marcar COMPLETED (idempotente + dispara handoff) |

### Tarefas (Delegação entre Agentes)
| Tool | Quando usar |
|---|---|
| `aiops_delegate_task` | Delegar trabalho para outro agente |
| `aiops_consume_pending_tasks` | No início — verificar tarefas pendentes |
| `aiops_get_task` | Verificar se tarefa delegada foi concluída |

### Logs e Conhecimento
| Tool | Quando usar |
|---|---|
| `aiops_send_agent_log` | Registrar TODA ação significativa |
| `aiops_list_agent_logs` | Auditar ações com filtro por tipo |
| `aiops_hive_mind_search` | Buscar soluções ANTES de pesquisar na web |
| `aiops_create_knowledge` | Persistir aprendizado novo para todos os agentes |
| `aiops_list_knowledge` | Verificar skills/workflows antes de criar novos |
| `aiops_evaluate_agent` | Auto-avaliação LLM de performance |

### Sprint 4 — Infraestrutura & Real-Time (5 tools)
| Tool | Quando usar |
|---|---|
| `redis_query` | Inspecionar/debugar cache Redis (GET, SET, KEYS, HGETALL, SCAN…) |
| `service_health_check` | Verificar se portas/endpoints estão UP (TCP + HTTP em paralelo) |
| `vault_get_secret` | Validar presença de variáveis de ambiente — Zero-Trust (nunca expõe valores) |
| `notify_agent` | Enviar notificação estruturada a outro agente via EventBus do Maestro |
| `ws_emit` | Emitir evento real-time para o dashboard WebSocket via Maestro |

### Fluxo Obrigatório do Agente

```
1. aiops_consume_pending_tasks  → Checar tarefas pendentes
2. aiops_hive_mind_search       → Buscar conhecimento
3. aiops_send_agent_log         → Logar início
4.  ... trabalho ...
5. aiops_create_knowledge       → Persistir aprendizado (se novo)
6. aiops_complete_stage         → Marcar etapa concluída
```
