---
name: Tauri (+ Frontend)
description: Validate, generate, and architect Tauri desktop applications enforcing IPC security boundaries, Rust command safety, permission scoping, and frontend-backend communication best practices.
---

# Tauri — Diretrizes Sênior

## 1. Zero-Trust & Limites de Contexto

- **Antes de gerar qualquer feature**, externalize a arquitetura proposta em um artefato (`AI.md` ou `/brain/`).
- Faça **micro-commits**: edite um comando Rust ou um componente frontend por vez.
- Após concluir uma feature, **finalize a task** explicitamente para liberar contexto.
- O frontend é **território hostil**. Todo dado vindo do WebView deve ser tratado como input malicioso.

## 2. Estrutura de Projeto

```
src-tauri/
├── src/
│   ├── main.rs            # Entry point
│   ├── lib.rs             # app builder + plugins
│   ├── commands/          # Comandos Tauri (IPC handlers)
│   │   ├── mod.rs
│   │   ├── auth.rs
│   │   └── files.rs
│   ├── state.rs           # App state (Mutex<T>)
│   └── errors.rs          # Error types
├── capabilities/          # Permissões declarativas
├── Cargo.toml
└── tauri.conf.json

src/                       # Frontend (Vue/React/Svelte)
├── lib/
│   ├── tauri.ts           # Wrappers tipados para invoke()
│   └── types.ts           # Tipos compartilhados
└── ...
```

## 3. IPC Security — Fronteira Crítica

### 3.1 Sempre validar inputs nos comandos Rust

```rust
// ✅ CERTO — validação explícita, Result<T, E>, serde tipado
#[derive(Debug, Deserialize)]
struct CreateFileInput {
    name: String,
    content: String,
}

#[tauri::command]
async fn create_file(input: CreateFileInput) -> Result<String, AppError> {
    // Validar ANTES de qualquer operação
    if input.name.contains("..") || input.name.contains('/') {
        return Err(AppError::Validation("Nome de arquivo inválido".into()));
    }
    if input.content.len() > 10_000_000 {
        return Err(AppError::Validation("Conteúdo muito grande".into()));
    }

    let path = app_data_dir().join(&input.name);
    tokio::fs::write(&path, &input.content).await?;
    Ok(path.display().to_string())
}

// ❌ ERRADO — sem validação, panic em erro, path traversal vulnerável
#[tauri::command]
fn create_file(name: String, content: String) -> String {
    let path = format!("/data/{}", name);  // PATH TRAVERSAL!
    std::fs::write(&path, &content).unwrap();  // PANIC em erro!
    path
}
```

### 3.2 Error handling com tipos próprios

```rust
// ✅ CERTO — tipo de erro que serializa para frontend
#[derive(Debug, thiserror::Error)]
enum AppError {
    #[error("Validação: {0}")]
    Validation(String),
    #[error("IO: {0}")]
    Io(#[from] std::io::Error),
    #[error("Database: {0}")]
    Database(String),
}

impl serde::Serialize for AppError {
    fn serialize<S: serde::Serializer>(&self, s: S) -> Result<S::Ok, S::Error> {
        s.serialize_str(&self.to_string())
    }
}

// ❌ ERRADO — String como erro (perde contexto)
#[tauri::command]
fn do_thing() -> Result<String, String> {
    Err("deu ruim".to_string())  // Sem tipagem, sem contexto
}
```

## 4. Capabilities — Permissões Explícitas

```json
// capabilities/main.json
{
  "identifier": "main-capability",
  "windows": ["main"],
  "permissions": [
    "core:default",
    "fs:allow-read-file",
    "fs:allow-write-file",
    "dialog:allow-open",
    "shell:allow-open"
  ]
}
```

- **Princípio do menor privilégio**: habilitar APENAS as permissões necessárias.
- Nunca usar `fs:allow-*` sem escopo de diretório.
- Scopes restritivos:

```json
{
  "permissions": ["fs:allow-read-file"],
  "scope": {
    "allow": [{ "path": "$APPDATA/**" }],
    "deny": [{ "path": "$APPDATA/secrets/**" }]
  }
}
```

## 5. Frontend — Wrappers Tipados

```typescript
// ✅ CERTO — wrapper tipado com error handling
import { invoke } from "@tauri-apps/api/core";

interface CreateFileInput {
  name: string;
  content: string;
}

export async function createFile(input: CreateFileInput): Promise<string> {
  return invoke<string>("create_file", { input });
}

// ❌ ERRADO — invoke direto sem tipagem
const result = await invoke("create_file", { name: "foo", content: "bar" });
// Sem tipo de retorno, sem tipo de input
```

## 6. Performance

- **Async commands** (`async fn`) para I/O — nunca bloquear a main thread do Tauri.
- `State<Mutex<T>>` para estado compartilhado entre comandos.
- Bundler otimizado: ativar minificação e tree-shaking no frontend.
- Tamanho do bundle: monitorar com `cargo bloat` e `webpack-bundle-analyzer`.

## 7. Segurança

- CSP estrito no `tauri.conf.json` (`default-src 'self'`).
- Nunca carregar URLs externas no WebView principal.
- `dangerousRemoteDomainIpcAccess` é **PROIBIDO** em produção.
- Assinar o app para distribuição (code signing).
- Updater com chave pública para auto-updates seguros.
