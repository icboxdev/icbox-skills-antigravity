---
name: Tauri v2 (+ React Frontend)
description: Architect, generate, and validate Tauri v2 cross-platform applications (desktop + mobile) with React/TypeScript frontend. Enforces IPC security, ability-based permissions, typed invoke wrappers, the Isolation Pattern, and Rust command safety.
---

# 🦀 Tauri v2 + React Architecture & Security Mastery

This skill defines the architectural dogmas and absolute best practices for building cross-platform (Desktop & Mobile) applications using **Tauri v2** with a **Rust** backend and a **React/Next.js** frontend.

Tauri operates on a strict defense-in-depth model. The Rust backend is the **Trusted Boundary**, while the frontend WebView is the **Untrusted Boundary**.

## 🛡️ IPC Security & The Isolation Pattern

In Tauri v2, Inter-Process Communication (IPC) security is paramount.

### 1. The Isolation Pattern (Mandatory for High-Security Apps)
Tauri v2 highly recommends the **Isolation Pattern**. This injects a secure, isolated JavaScript environment between the frontend WebView and the Tauri Core.
*   **Dogma:** Use the Isolation Pattern to intercept, validate, and potentially modify all IPC messages *before* they reach the Rust backend. This mitigates supply chain attacks (e.g., a compromised npm package trying to call a backend file-delete command).

### 2. Capabilities and Permissions
Tauri v2 replaces the global allowlist with granular **Capabilities** and **Permissions**.
*   **Dogma:** Apply the Principle of Least Privilege. Only grant the exact permissions required by the frontend in the `tauri.conf.json` or capabilities files.
*   **Rule:** If a frontend component only needs to read a specific file, grant `fs:read` for that exact path, NEVER global `fs:all`.

```json
// CERTO: Granular Capability
{
  "identifier": "read-logs",
  "windows": ["main"],
  "permissions": [
    "core:default",
    {
      "identifier": "fs:allow-read",
      "allow": [{ "path": "$APPDATA/logs/*" }]
    }
  ]
}
```

### 3. Content Security Policy (CSP)
*   **Dogma:** A strict CSP MUST be defined in `tauri.conf.json` to prevent XSS attacks in the WebView. Restrict `script-src`, `connect-src`, and `img-src` to known boundaries.

## ⚙️ Rust Backend (The Trusted Layer)

The Rust backend handles all system-level operations, file I/O, database connections, and cryptography.

### 1. The Command Pattern (`#[tauri::command]`)
Expose Rust functions to the frontend exclusively via Tauri Commands.

*   **Dogma (Input Validation):** Treat ALL arguments coming from the frontend as malicious. Validate them heavily in Rust before processing.
*   **Dogma (Error Handling):** Commands MUST return `Result<T, E>`. The Error type `E` MUST implement `serde::Serialize`. Never panic! Map Rust errors to safe, generic strings before sending them to the frontend to avoid leaking system paths or stack traces.

```rust
// CERTO: Safe Command with Error Handling
#[derive(serde::Serialize)]
pub struct CommandError(String);

impl From<std::io::Error> for CommandError {
    fn from(err: std::io::Error) -> Self {
        // Log the real error in Rust, send a generic error to the UI
        tracing::error!("File specific error: {}", err);
        CommandError("Failed to fulfill filesystem request.".into())
    }
}

#[tauri::command]
pub fn secure_file_read(path: String) -> Result<String, CommandError> {
    // 1. VALIDATE: Ensure path doesn't contain "../" (Path Traversal)
    if path.contains("..") { return Err(CommandError("Invalid path".into())); }
    // 2. EXECUTE
    let content = std::fs::read_to_string(path)?;
    Ok(content)
}
```

### 2. State Management in Rust
Use Tauri's `State` to manage global variables, database pools, or application state safely across commands.
*   **Rule:** Wrap shared state in `std::sync::Mutex` or `tokio::sync::RwLock` to prevent data races.

```rust
// CERTO: Managed State
struct AppState {
    db_pool: sqlx::SqlitePool,
}

#[tauri::command]
async fn get_users(state: tauri::State<'_, AppState>) -> Result<Vec<User>, CommandError> {
    let users = sqlx::query_as!(User, "SELECT * FROM users").fetch_all(&state.db_pool).await.map_err(|e| CommandError(e.to_string()))?;
    Ok(users)
}
```

## ⚛️ React Frontend Integration

### 1. Typed IPC Invokers
*   **Dogma:** Do NOT use raw `invoke('command_name')` scattered throughout the codebase.
*   **Rule:** Create a dedicated `api.ts` or `bindings.ts` file that wraps `invoke` calls in perfectly typed asynchronous TypeScript functions. (Use tools like `ts-rs` to automatically generate TS interfaces from Rust structs).

```typescript
// CERTO: Typed Wrapper
import { invoke } from '@tauri-apps/api/core';

export async function secureFileRead(path: string): Promise<string> {
  return await invoke<string>('secure_file_read', { path });
}
```

### 2. Tauri Events (Server-to-Client)
For real-time updates (e.g., a long-running download in Rust updating a progress bar in React), use Tauri's Event system (`app.emit_all` in Rust, `listen` in TypeScript).
*   **Rule:** Always clean up event listeners in React `useEffect` cleanup functions to prevent memory leaks.

## 🚨 Anti-Patterns (DO NOT DO THIS)
*   ❌ **NEVER** store API keys, JWT secrets, or tokens in `localStorage` or the React codebase. The Rust backend MUST hold them and inject them into HTTP requests.
*   ❌ **NEVER** use bundled WebViews (like Electron or CEF). Tauri relies on the OS native WebView (WebView2, WKWebView) for automatic security updates.
*   ❌ **NEVER** trust input from `invoke`. Always sanitize in Rust.
*   ❌ **NEVER** use `window.location` or standard web routing for desktop apps without considering hash routing (or React Router's `createMemoryRouter`) to avoid filesystem routing bugs in production builds.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

