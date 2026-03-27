---
name: MCP Communication Mastery (Rust & Node.js)
description: Architect, generate, and validate Model Context Protocol (MCP) servers and clients using Rust (rmcp crate) and Node.js (@modelcontextprotocol/sdk). Enforces Zero-Token Omniscience, typed tool registration, Stdio/Streamable HTTP transports, cross-stack type parity (Serde ↔ Zod), and Zero-Trust security patterns.
---

# MCP Communication Mastery — Rust & Node.js

## 1. Propósito

Guia definitivo para construir **MCP Servers** e **MCP Clients** nas stacks Rust e Node.js/TypeScript. Cobre o protocolo JSON-RPC 2.0, registro de ferramentas (tools), transports (Stdio, Streamable HTTP), segurança M2M, e interoperabilidade cross-stack.

> Esta skill NÃO cobre o framework Antigravity MCP Core (que tem skill própria `antigravity-mcp-core-development`). Esta skill é para projetos MCP genéricos em Rust e Node.js.

## 2. Dogmas Arquiteturais

### 2.1 Zero-Token Omniscience
- **Processe dados pesados localmente** no MCP Server. NUNCA retorne logs brutos, dumps de banco ou saídas enormes.
- **Retorne apenas JSON denso e resumido** via `CallToolResult::success(vec![Content::text(...)])` (Rust) ou `{ content: [{ type: 'text', text: '...' }] }` (Node).
- Se a ferramenta lê um arquivo, retorne um resumo estruturado, NUNCA o conteúdo completo.

### 2.2 Typed Tool Registration
- **Rust**: SEMPRE usar `#[tool(description = "...")]` macro do `rmcp` + struct derivando `schemars::JsonSchema`, `serde::Deserialize`.
- **Node.js**: SEMPRE usar `server.registerTool('name', { inputSchema: z.object({...}) }, callback)`. NUNCA usar raw shape sem `z.object()` (breaking change v2).
- **Cada ferramenta DEVE ter `description`** claro e conciso. Ferramentas sem descrição são inúteis para o LLM.
- **inputSchema obrigatório** em toda ferramenta que aceita parâmetros. Use `z.object({})` ou `Parameters<JsonObject>` para tools sem args.

### 2.3 Transport Selection
| Transport | Quando Usar | Stack |
|-----------|------------|-------|
| **Stdio** (`stdin/stdout`) | MCP local, sub-processo, pipe direto | Rust: `(stdin(), stdout())` / Node: `StdioServerTransport` |
| **Streamable HTTP** | MCP remoto/cloud, multi-sessão | Rust: `hyper` + feature `streamable-http-server` / Node: `StreamableHTTPServerTransport` |

- **Preferir Stdio** para comunicação local de baixa latência (agentes locais, CLI tools).
- **Usar Streamable HTTP** apenas quando há necessidade de sessões remotas, autenticação OAuth, ou multi-client.

### 2.4 Zero-Trust Security
- **NUNCA** expor secrets (API Keys, DB passwords, tokens) nas respostas das ferramentas.
- **Ferramentas de introspecção** (env vars, secrets) DEVEM retornar apenas status (presente/ausente), NUNCA valores.
- **M2M Authentication**: Usar header `X-Master-Key` com comparação timing-safe (`timingSafeEqual` em Node.js, `subtle::ConstantTimeEq` em Rust).
- **Scripts temporários** gerados por MCP tools DEVEM ser criados em `/tmp/` e removidos imediatamente após uso.

### 2.5 Cross-Stack Type Parity (Serde ↔ Zod)
- Quando Rust e Node.js MCP servers se comunicam, garantir **paridade de tipos**:
  - `String` (Rust) ↔ `z.string()` (Zod)
  - `i32/i64` (Rust) ↔ `z.number()` (Zod)
  - `Option<T>` (Rust) ↔ `z.optional(T)` (Zod)
  - `Vec<T>` (Rust) ↔ `z.array(T)` (Zod)
  - `serde_json::Value` (Rust) ↔ `z.unknown()` (Zod)
- **Renaming**: Usar `#[serde(rename_all = "camelCase")]` em Rust se o client espera camelCase.
- **Validação obrigatória** em ambos os lados. NUNCA confiar em dados recebidos sem validar.

### 2.6 Error Handling
- **Rust**: Retornar `Result<CallToolResult, McpError>` onde `McpError = rmcp::ErrorData`. Usar `McpError::resource_not_found()`, `McpError::invalid_params()`.
- **Node.js**: Retornar `{ content: [{ type: 'text', text: 'Error: ...' }], isError: true }` para erros de ferramenta.
- **NUNCA** panics em tool handlers. Todo erro deve ser capturado e retornado via protocolo MCP.

## 3. Rust — Padrão `rmcp`

### 3.1 Cargo.toml
```toml
[dependencies]
rmcp = { version = "1.3", features = ["server", "transport-io"] }
rmcp-macros = "1.3"
schemars = "1.1"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
tokio = { version = "1", features = ["full"] }
tracing = "0.1"
tracing-subscriber = "0.3"
```

### 3.2 Server Mínimo (Stdio)
```rust
// ✅ CERTO — Servidor MCP Rust com #[tool] macro
use rmcp::{
    ErrorData as McpError, ServerHandler, ServiceExt,
    handler::server::{router::tool::ToolRouter, wrapper::Parameters},
    model::*, schemars, tool, tool_handler, tool_router,
    service::RequestContext, RoleServer,
};

#[derive(Debug, serde::Deserialize, schemars::JsonSchema)]
pub struct SumRequest {
    /// First number
    pub a: i32,
    /// Second number
    pub b: i32,
}

#[derive(Clone)]
pub struct Calculator {
    tool_router: ToolRouter<Calculator>,
}

#[tool_router]
impl Calculator {
    pub fn new() -> Self {
        Self { tool_router: Self::tool_router() }
    }

    #[tool(description = "Calculate the sum of two numbers")]
    fn sum(
        &self,
        Parameters(SumRequest { a, b }): Parameters<SumRequest>,
    ) -> Result<CallToolResult, McpError> {
        Ok(CallToolResult::success(vec![Content::text(
            (a + b).to_string(),
        )]))
    }

    #[tool(description = "Get current server time as ISO 8601")]
    fn now(&self) -> Result<CallToolResult, McpError> {
        let now = chrono::Utc::now().to_rfc3339();
        Ok(CallToolResult::success(vec![Content::text(now)]))
    }
}

#[tool_handler]
impl ServerHandler for Calculator {
    fn get_info(&self) -> ServerInfo {
        ServerInfo::new(
            ServerCapabilities::builder().enable_tools().build(),
        )
        .with_server_info(Implementation::from_build_env())
    }
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt().init();
    let service = Calculator::new();
    let server = service.serve(tokio::io::stdio()).await?;
    server.waiting().await?;
    Ok(())
}
```

```rust
// ❌ ERRADO — Registrando tools manualmente sem macro
impl ServerHandler for Calculator {
    async fn list_tools(&self, ...) -> Result<ListToolsResult, McpError> {
        // NÃO! Use #[tool_router] + #[tool] macro para registro automático
        Ok(ListToolsResult {
            tools: vec![Tool { name: "sum".into(), ... }],
            ..
        })
    }
}
```

### 3.3 Macro Patterns

| Padrão | Uso |
|--------|-----|
| `#[tool(description = "...")]` | Registra método como tool MCP |
| `Parameters<T>` | Extrai e valida args via `JsonSchema` |
| `#[tool_router]` no `impl` | Gera `Self::tool_router()` com registro automático |
| `#[tool_handler]` no `impl ServerHandler` | Conecta o router ao handler |
| `RequestContext<RoleServer>` | Acesso ao peer, extensions, session |

### 3.4 Estado Compartilhado
```rust
// ✅ CERTO — Estado thread-safe com Arc<Mutex<T>>
#[derive(Clone)]
pub struct MyServer {
    state: Arc<Mutex<AppState>>,
    tool_router: ToolRouter<MyServer>,
}

#[tool_router]
impl MyServer {
    #[tool(description = "Read current state")]
    async fn get_state(&self) -> Result<CallToolResult, McpError> {
        let state = self.state.lock().await;
        Ok(CallToolResult::success(vec![Content::text(
            serde_json::to_string(&*state).unwrap(),
        )]))
    }
}
```

### 3.5 ServerInfo & Capabilities
```rust
fn get_info(&self) -> ServerInfo {
    ServerInfo::new(
        ServerCapabilities::builder()
            .enable_tools()        // Habilita tools
            .enable_resources()    // Habilita resources (file://, memo://)
            .enable_prompts()      // Habilita prompts
            .enable_logging()      // Habilita logging notifications
            .build(),
    )
    .with_server_info(Implementation::from_build_env())
    .with_instructions("Descrição do que este server faz.".to_string())
}
```

## 4. Node.js — Padrão `@modelcontextprotocol/sdk`

### 4.1 Dependências
```json
{
  "dependencies": {
    "@modelcontextprotocol/sdk": "^2.0.0",
    "zod": "^3.24"
  }
}
```

### 4.2 Server Mínimo (Stdio)
```typescript
// ✅ CERTO — Servidor MCP Node.js com registerTool v2
import { McpServer } from '@modelcontextprotocol/server';
import { StdioServerTransport } from '@modelcontextprotocol/server/stdio';
import * as z from 'zod/v4';

const server = new McpServer({
  name: 'my-tools',
  version: '1.0.0',
});

// Tool com schema validado via Zod
server.registerTool(
  'calculate-sum',
  {
    title: 'Sum Calculator',
    description: 'Calculate the sum of two numbers',
    inputSchema: z.object({
      a: z.number().describe('First number'),
      b: z.number().describe('Second number'),
    }),
  },
  async ({ a, b }) => ({
    content: [{ type: 'text', text: String(a + b) }],
  })
);

// Tool sem parâmetros
server.registerTool(
  'server-time',
  {
    title: 'Server Time',
    description: 'Get current server time as ISO 8601',
    inputSchema: z.object({}),
  },
  async () => ({
    content: [{ type: 'text', text: new Date().toISOString() }],
  })
);

const transport = new StdioServerTransport();
await server.connect(transport);
```

```typescript
// ❌ ERRADO — v1 raw shape (BREAKING em v2)
server.registerTool('greet', {
  inputSchema: { name: z.string() }, // ← Falta z.object() wrapper
}, callback);

// ❌ ERRADO — Sem description
server.registerTool('mystery-tool', {
  inputSchema: z.object({ x: z.number() }),
}, callback);
// ↑ O LLM não sabe o que essa ferramenta faz
```

### 4.3 Context API (Logging & Peer Requests)
```typescript
server.registerTool(
  'fetch-data',
  {
    description: 'Fetch and analyze data from URL',
    inputSchema: z.object({ url: z.url() }),
  },
  async ({ url }, ctx) => {
    await ctx.mcpReq.log('info', `Fetching ${url}`);
    const res = await fetch(url);
    const text = await res.text();
    // Zero-Token: retornar resumo, não o conteúdo completo
    const summary = `Status: ${res.status}, Size: ${text.length} bytes`;
    return { content: [{ type: 'text', text: summary }] };
  }
);
```

### 4.4 Streamable HTTP Transport (Remoto)
```typescript
import { McpServer } from '@modelcontextprotocol/server';
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/server/streamableHttp';
import express from 'express';

const app = express();
app.use(express.json());

const server = new McpServer({ name: 'remote-tools', version: '1.0.0' });
// ... registerTool calls ...

app.post('/mcp', async (req, res) => {
  const transport = new StreamableHTTPServerTransport('/mcp', res, {
    sessionIdGenerator: () => crypto.randomUUID(),
  });
  await server.connect(transport);
  await transport.handleRequest(req, res);
});

app.listen(3001);
```

## 5. Cross-Stack Communication (Rust ↔ Node.js)

### 5.1 Rust Client → Node MCP Server
```rust
use rmcp::{ServiceExt, transport::TokioChildProcess};
use tokio::process::Command;

let client = ().serve(
    TokioChildProcess::new(Command::new("node").arg("./server.js"))?
).await?;

// Chamar tool do server Node
let result = client.call_tool(CallToolRequestParams::new("calculate-sum")
    .with_arguments(rmcp::object!({ "a": 10, "b": 20 }))
).await?;
```

### 5.2 Node Client → Rust MCP Server
```typescript
import { Client } from '@modelcontextprotocol/client';
import { StdioClientTransport } from '@modelcontextprotocol/client/stdio';

const transport = new StdioClientTransport({
  command: './target/release/my-mcp-server',
  args: [],
});

const client = new Client({ name: 'node-client', version: '1.0.0' });
await client.connect(transport);

const result = await client.callTool({
  name: 'calculate-sum',
  arguments: { a: 10, b: 20 },
});
```

### 5.3 Contrato de Tipos
```rust
// Rust: Input struct
#[derive(Debug, serde::Deserialize, schemars::JsonSchema)]
#[serde(rename_all = "camelCase")]
pub struct CreateUserInput {
    pub full_name: String,       // → fullName no JSON
    pub email: String,
    pub age: Option<i32>,        // → opcional
    pub tags: Vec<String>,       // → array
}
```

```typescript
// Node.js: Schema equivalente Zod
const CreateUserSchema = z.object({
  fullName: z.string(),          // ← Match com camelCase Rust
  email: z.string().email(),
  age: z.number().optional(),    // ← Match com Option<i32>
  tags: z.array(z.string()),     // ← Match com Vec<String>
});
```

## 6. Security Patterns

### 6.1 M2M Authentication (Tool-Level)
```rust
// ✅ Rust — Validar caller secret no tool handler
#[tool(description = "Admin-only: introspect database")]
async fn introspect_db(
    &self,
    ctx: RequestContext<RoleServer>,
) -> Result<CallToolResult, McpError> {
    // Extrair secret do header HTTP (Streamable HTTP transport)
    let parts = ctx.extensions.get::<axum::http::request::Parts>()
        .ok_or_else(|| McpError::invalid_params("Missing HTTP context", None))?;
    let caller_key = parts.headers.get("x-master-key")
        .and_then(|v| v.to_str().ok())
        .ok_or_else(|| McpError::invalid_params("Missing X-Master-Key", None))?;
    
    let expected = std::env::var("MASTER_KEY")
        .map_err(|_| McpError::internal_error("MASTER_KEY not configured", None))?;
    
    if caller_key != expected {
        return Err(McpError::invalid_params("Unauthorized", None));
    }
    
    // ... lógica segura ...
    Ok(CallToolResult::success(vec![Content::text("OK")]))
}
```

### 6.2 Env Guard (Zero-Trust Secrets)
```typescript
// ✅ Node.js — Tool que verifica env vars sem expor valores
server.registerTool(
  'env-check',
  {
    description: 'Check if required environment variables are present (never returns values)',
    inputSchema: z.object({
      keys: z.array(z.string()).describe('Environment variable names to check'),
    }),
  },
  async ({ keys }) => {
    const result = keys.map(key => ({
      key,
      present: process.env[key] !== undefined,
    }));
    return {
      content: [{ type: 'text', text: JSON.stringify(result) }],
    };
  }
);
```

## 7. Testing

### 7.1 Rust — In-Process Test
```rust
#[tokio::test]
async fn test_calculator_sum() -> anyhow::Result<()> {
    let server = Calculator::new();
    let client = rmcp::ClientHandler::default();
    
    let (server_transport, client_transport) = tokio::io::duplex(4096);
    let server_handle = tokio::spawn(async move {
        server.serve(server_transport).await?.waiting().await
    });
    
    let client_service = client.serve(client_transport).await?;
    let result = client_service.call_tool(
        CallToolRequestParams::new("sum")
            .with_arguments(rmcp::object!({ "a": 5, "b": 3 }))
    ).await?;
    
    assert_eq!(result.content[0].as_text().unwrap().text, "8");
    
    client_service.cancel().await?;
    let _ = server_handle.await;
    Ok(())
}
```

### 7.2 Node.js — Direct Handler Test
```typescript
import { describe, it, expect } from 'vitest';

// Testar o handler diretamente, sem transport
describe('calculate-sum', () => {
  it('should return correct sum', async () => {
    const handler = async ({ a, b }: { a: number; b: number }) => ({
      content: [{ type: 'text' as const, text: String(a + b) }],
    });
    
    const result = await handler({ a: 5, b: 3 });
    expect(result.content[0].text).toBe('8');
  });
});
```

## 8. Checklist de Implementação

- [ ] **Servidor definido** com `ServerInfo` e capabilities explícitas
- [ ] **Todas as tools** registradas com `description` e `inputSchema`
- [ ] **Transport escolhido** (Stdio para local, Streamable HTTP para remoto)
- [ ] **Tipos derivando** `JsonSchema + Deserialize` (Rust) ou `z.object()` (Node)
- [ ] **Erros capturados** e retornados via protocolo (sem panics)
- [ ] **Secrets protegidos** — nenhum valor exposto nas respostas
- [ ] **Paridade de tipos** validada entre Rust e Node.js (se cross-stack)
- [ ] **Testes in-process** com duplex transport (Rust) ou handler direto (Node)
- [ ] **Logging estruturado** via `tracing` (Rust) ou `ctx.mcpReq.log()` (Node)

## 9. Constraints — O que NUNCA Fazer

- ❌ NUNCA retornar dados brutos (logs completos, dumps) em respostas de ferramentas
- ❌ NUNCA usar raw shapes em `inputSchema` Node.js (v2 exige `z.object()`)
- ❌ NUNCA omitir `description` em ferramentas — o LLM precisa saber o que a tool faz
- ❌ NUNCA fazer `panic!()` ou `unwrap()` em tool handlers Rust — usar `?` com `McpError`
- ❌ NUNCA expor valores de variáveis de ambiente, API keys, ou tokens em respostas
- ❌ NUNCA implementar `list_tools` manualmente — usar `#[tool_router]` macro
- ❌ NUNCA criar scripts auxiliares dentro da árvore do projeto — usar `/tmp/`
- ❌ NUNCA confiar em dados de entrada sem validação (tanto Rust quanto Node.js)
- ❌ NUNCA misturar lógica de negócio no handler MCP — delegar para services/modules
