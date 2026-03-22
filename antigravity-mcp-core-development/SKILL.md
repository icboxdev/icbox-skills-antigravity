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

### Registro no `index.ts` (CERTO ✅)
```typescript
import { projectInspectorTool, handleProjectInspector } from './tools/project_inspector.js';

server.setRequestHandler(ListToolsRequestSchema, async () => {
    return {
        tools: [
            projectInspectorTool, // <-- Adicionando aqui
        ],
    };
});

server.setRequestHandler(CallToolRequestSchema, async (request) => {
    switch (request.params.name) {
        case "project_inspector":     // <-- Interceptando aqui
            return await handleProjectInspector(request.params.arguments || {});
        default:
            throw new Error(`Tool not found: \${request.params.name}`);
    }
});
```
