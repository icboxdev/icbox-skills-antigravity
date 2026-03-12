---
name: Tauri v2 (+ React Frontend)
description: Architect, generate, and validate Tauri v2 cross-platform applications (desktop + mobile) with React/TypeScript frontend. Enforces IPC security, capability-based permissions, typed invoke wrappers, Channel streaming, plugin ecosystem, and Rust command safety.
---

# Tauri v2 + React — Diretrizes Sênior

## 1. Zero-Trust & Limites de Contexto

- **Antes de gerar qualquer feature**, externalize a arquitetura proposta em um artefato (`AI.md` ou `/brain/`).
- Faça **micro-commits**: edite um comando Rust ou um componente React por vez.
- Após concluir uma feature, **finalize a task** explicitamente para liberar contexto.
- O frontend é **território hostil**. Todo dado vindo do WebView deve ser tratado como input malicioso.
- Em Tauri v2, o `allowlist` foi **removido** — use `capabilities` + `permissions` + `scopes`.

## 2. Estrutura de Projeto

```
src-tauri/
├── src/
│   ├── main.rs              # Desktop entry point
│   ├── lib.rs               # App builder + plugins (mobile entry point)
│   ├── commands/             # Comandos Tauri (IPC handlers)
│   │   ├── mod.rs
│   │   ├── auth.rs
│   │   └── files.rs
│   ├── state.rs              # App state (Mutex<T>)
│   └── errors.rs             # Error types (thiserror + Serialize)
├── capabilities/             # Permissões declarativas (v2)
│   └── default.json
├── Cargo.toml
└── tauri.conf.json

src/                          # Frontend React + TypeScript
├── lib/
│   ├── tauri.ts              # Wrappers tipados para invoke()
│   ├── hooks/
│   │   ├── use-tauri-event.ts  # Hook para eventos Tauri
│   │   └── use-tauri-invoke.ts # Hook para invoke com loading/error
│   └── types.ts              # Tipos compartilhados (espelham Rust)
├── components/
├── store/                    # Zustand stores (frontend state)
└── ...
```

### Setup de Projeto

```bash
# Criar projeto Tauri v2 + React
npm create tauri-app@latest -- --template react-ts

# Ou com pnpm
pnpm create tauri-app --template react-ts

# Dev desktop
pnpm tauri dev

# Dev mobile
pnpm tauri android dev
pnpm tauri ios dev
```

## 3. IPC Security — Fronteira Crítica

### 3.1 Três Primitivos IPC em Tauri v2

| Primitivo | Direção | Uso |
|-----------|---------|-----|
| **Commands** (`invoke`) | Frontend → Rust | RPC tipado, request/response |
| **Events** (`emit/listen`) | Bidirecional | Fire-and-forget, lifecycle, broadcasts |
| **Channels** | Rust → Frontend (streaming) | Alta throughput, dados ordenados, progresso |

### 3.2 Sempre validar inputs nos comandos Rust

```rust
// ✅ CERTO — validação explícita, Result<T, E>, serde tipado
#[derive(Debug, Deserialize)]
struct CreateFileInput {
    name: String,
    content: String,
}

#[tauri::command]
async fn create_file(input: CreateFileInput) -> Result<String, AppError> {
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

### 3.3 Error handling com tipos próprios

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
    Err("deu ruim".to_string())
}
```

### 3.4 Channels — Streaming de Alta Throughput (NOVO v2)

Para streaming de dados (progresso, chunks de arquivo, logs em tempo real), use **Channels** ao invés de Events.

```rust
// ✅ CERTO — Channel tipado para streaming de progresso
use tauri::ipc::Channel;
use serde::Serialize;

#[derive(Clone, Serialize)]
#[serde(tag = "event", content = "data")]
enum DownloadEvent {
    Started { url: String, size: u64 },
    Progress { bytes: u64 },
    Finished,
}

#[tauri::command]
async fn download_file(url: String, on_event: Channel<DownloadEvent>) {
    on_event.send(DownloadEvent::Started {
        url: url.clone(), size: 1000
    }).unwrap();

    for bytes in [100, 300, 600, 1000] {
        on_event.send(DownloadEvent::Progress { bytes }).unwrap();
    }

    on_event.send(DownloadEvent::Finished).unwrap();
}
```

```typescript
// ✅ CERTO — Frontend: consumindo Channel tipado
import { invoke, Channel } from '@tauri-apps/api/core';

type DownloadEvent =
  | { event: 'Started'; data: { url: string; size: number } }
  | { event: 'Progress'; data: { bytes: number } }
  | { event: 'Finished' };

const channel = new Channel<DownloadEvent>();
channel.onmessage = (message) => {
  if (message.event === 'Progress') {
    console.log(`Downloaded ${message.data.bytes} bytes`);
  }
};

await invoke('download_file', {
  url: 'https://example.com/file.zip',
  onEvent: channel,
});
```

## 4. Capabilities — Permissões Explícitas (v2)

O `allowlist` do Tauri v1 foi **removido**. Em v2, use `capabilities/`:

```json
// capabilities/default.json
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
- Prefixo `core:` obrigatório para permissões do core.
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

## 5. Frontend React — Wrappers e Hooks Tipados

### 5.1 Wrapper de invoke tipado

```typescript
// ✅ CERTO — wrapper tipado com Zod para zero-trust
import { invoke } from '@tauri-apps/api/core';
import { z } from 'zod';

// Schemas compartilhados
const CreateFileInput = z.object({
  name: z.string().min(1).max(255),
  content: z.string().max(10_000_000),
});

type CreateFileInput = z.infer<typeof CreateFileInput>;

export async function createFile(input: CreateFileInput): Promise<string> {
  const validated = CreateFileInput.parse(input); // valida ANTES
  return invoke<string>('create_file', { input: validated });
}

// ❌ ERRADO — invoke direto sem tipagem
const result = await invoke('create_file', { name: 'foo', content: 'bar' });
// Sem tipo de retorno, sem tipo de input
```

### 5.2 Hook useTauriEvent — Eventos com Cleanup

```typescript
// ✅ CERTO — hook tipado com cleanup automático
import { useEffect } from 'react';
import { listen, type UnlistenFn } from '@tauri-apps/api/event';

type EventMap = {
  'file-changed': { path: string };
  'sync-status': { connected: boolean };
};

export function useTauriEvent<K extends keyof EventMap>(
  event: K,
  handler: (payload: EventMap[K]) => void,
) {
  useEffect(() => {
    let unlisten: UnlistenFn;

    const setup = async () => {
      unlisten = await listen<EventMap[K]>(event, (e) => {
        handler(e.payload);
      });
    };

    setup();

    return () => {
      unlisten?.();
    };
  }, [event, handler]);
}

// ❌ ERRADO — sem cleanup, memory leak em React Strict Mode
useEffect(() => {
  listen('file-changed', (e) => console.log(e));
  // NUNCA retorna unlisten!
}, []);
```

### 5.3 Hook useInvoke — Loading + Error automáticos

```typescript
// ✅ CERTO — hook para invoke com estado de loading/error
import { useState, useCallback } from 'react';
import { invoke } from '@tauri-apps/api/core';

interface InvokeState<T> {
  data: T | null;
  loading: boolean;
  error: string | null;
}

export function useInvoke<TArgs, TResult>(
  command: string,
) {
  const [state, setState] = useState<InvokeState<TResult>>({
    data: null,
    loading: false,
    error: null,
  });

  const execute = useCallback(async (args?: TArgs) => {
    setState((prev) => ({ ...prev, loading: true, error: null }));
    try {
      const data = await invoke<TResult>(command, args ?? {});
      setState({ data, loading: false, error: null });
      return data;
    } catch (err) {
      const error = err instanceof Error ? err.message : String(err);
      setState({ data: null, loading: false, error });
      throw err;
    }
  }, [command]);

  return { ...state, execute };
}
```

## 6. State Management

### 6.1 Frontend — Zustand (recomendado)

```typescript
// ✅ CERTO — Zustand para estado frontend do app
import { create } from 'zustand';

interface AppState {
  connected: boolean;
  setConnected: (v: boolean) => void;
}

export const useAppStore = create<AppState>((set) => ({
  connected: false,
  setConnected: (connected) => set({ connected }),
}));
```

### 6.2 Backend Rust — State<Mutex<T>>

```rust
// ✅ CERTO — estado compartilhado entre comandos
use std::sync::Mutex;
use tauri::State;

struct AppState {
    counter: Mutex<u32>,
}

#[tauri::command]
async fn increment(state: State<'_, AppState>) -> Result<u32, AppError> {
    let mut counter = state.counter.lock().unwrap();
    *counter += 1;
    Ok(*counter)
}

// No lib.rs:
tauri::Builder::default()
    .manage(AppState { counter: Mutex::new(0) })
    .invoke_handler(tauri::generate_handler![increment])
```

## 7. Plugins Oficiais v2

Tauri v2 modularizou funcionalidades em plugins. Instalar conforme necessário:

| Plugin | Crate | NPM | Uso |
|--------|-------|-----|-----|
| **Store** | `tauri-plugin-store` | `@tauri-apps/plugin-store` | Key-value persistente |
| **Dialog** | `tauri-plugin-dialog` | `@tauri-apps/plugin-dialog` | Diálogos nativos |
| **FS** | `tauri-plugin-fs` | `@tauri-apps/plugin-fs` | Acesso a arquivos |
| **Notification** | `tauri-plugin-notification` | `@tauri-apps/plugin-notification` | Notificações desktop/mobile |
| **Clipboard** | `tauri-plugin-clipboard-manager` | `@tauri-apps/plugin-clipboard-manager` | Clipboard do sistema |
| **Autostart** | `tauri-plugin-autostart` | `@tauri-apps/plugin-autostart` | Iniciar com o sistema |
| **Deep Link** | `tauri-plugin-deep-link` | `@tauri-apps/plugin-deep-link` | URL schemes customizados |
| **Updater** | `tauri-plugin-updater` | `@tauri-apps/plugin-updater` | Auto-update com assinatura |
| **Stronghold** | `tauri-plugin-stronghold` | `@tauri-apps/plugin-stronghold` | Secrets seguros (IOTA) |
| **Biometric** | `tauri-plugin-biometric` | `@tauri-apps/plugin-biometric` | Face ID / Fingerprint (mobile) |
| **Barcode** | `tauri-plugin-barcode-scanner` | `@tauri-apps/plugin-barcode-scanner` | QR/EAN scanner (mobile) |

### Padrão de uso de plugins

```rust
// src-tauri/src/lib.rs
tauri::Builder::default()
    .plugin(tauri_plugin_store::Builder::default().build())
    .plugin(tauri_plugin_dialog::init())
    .plugin(tauri_plugin_fs::init())
    .invoke_handler(tauri::generate_handler![/* commands */])
    .run(tauri::generate_context!())
    .expect("error while running tauri application");
```

```typescript
// Frontend: usar APIs do plugin
import { save } from '@tauri-apps/plugin-dialog';
import { writeTextFile } from '@tauri-apps/plugin-fs';

const path = await save({ defaultPath: 'output.txt' });
if (path) {
  await writeTextFile(path, 'Hello from Tauri v2!');
}
```

## 8. Mobile (Android + iOS) — NOVO v2

Tauri v2 suporta nativamente Android e iOS:

- `src-tauri/src/lib.rs` = entry point mobile
- `src-tauri/src/main.rs` = entry point desktop
- Plugins mobile-only: `biometric`, `barcode-scanner`
- Comandos de dev:

```bash
pnpm tauri android init   # Inicializa projeto Android
pnpm tauri ios init        # Inicializa projeto iOS
pnpm tauri android dev     # Dev com hot-reload
pnpm tauri ios dev         # Dev com hot-reload
pnpm tauri android build   # Build release
pnpm tauri ios build       # Build release
```

## 9. Configuração tauri.conf.json (v2)

Mudanças críticas vs v1:

| v1 | v2 |
|----|----|
| `tauri.allowlist` | **Removido** → usar `capabilities/` |
| `tauri.updater` | `plugins.updater` + `bundle.updater` |
| `tauri.cli` | `plugins.cli` |
| `build.distDir` | `frontendDist` |
| `build.devPath` | `devUrl` (apenas URLs) |
| `tauri {}` | `app {}` |
| `tauri.bundle` | `bundle` (top-level) |
| `system-tray` | `tray-icon` |

## 10. Performance

- **Async commands** (`async fn`) para I/O — nunca bloquear a main thread.
- `State<Mutex<T>>` para estado compartilhado entre comandos.
- **Channels** para streaming pesado (melhor que Events para alta throughput).
- Bundler otimizado: ativar minificação e tree-shaking no frontend.
- Tamanho do bundle: monitorar com `cargo bloat` e `vite-plugin-visualizer`.
- Lazy loading de componentes React com `React.lazy()` + `Suspense`.

## 11. Segurança

- CSP estrito no `tauri.conf.json` (`default-src 'self'`).
- Nunca carregar URLs externas no WebView principal.
- `dangerousRemoteDomainIpcAccess` é **PROIBIDO** em produção.
- Assinar o app para distribuição (code signing).
- Updater com chave pública para auto-updates seguros.
- **Biometric**: se enrollment mudar, chaves anteriores ficam inacessíveis.
- **Stronghold**: Vault API impede leitura direta de secrets (write-only).

## 12. Resumo Operacional

Quando atuar como Engenheiro Tauri v2 + React:

1. Projete a fronteira IPC antes de codar (quais commands, events, channels).
2. Valide inputs em **ambos os lados** (Zod no React + validação no Rust).
3. Use Channels para streaming, Events para lifecycle, Commands para RPC.
4. Capabilities com menor privilégio — nunca `*:allow-*` sem scope.
5. Zustand para estado frontend, `State<Mutex<T>>` para backend Rust.
6. Plugins oficiais antes de implementar manualmente funcionalidades nativas.
7. Cleanup de listeners no React (`useEffect` return + unlisten).
8. Async commands sempre — síncrono só para operações triviais CPU-bound.
