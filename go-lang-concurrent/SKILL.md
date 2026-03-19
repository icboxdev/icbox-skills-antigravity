---
name: Go Lang & Concurrency Architecture
description: Architect, generate, and validate Go (Golang) applications enforcing idiomatic concurrency. Covers Goroutines, Channels, Worker Pools, Context API propagation, and performance profiling. Enforces "share memory by communicating" dogma.
---

# 🐹 Go (Golang) Concurrency & Architecture Mastery

This skill defines the architectural dogmas and absolute best practices for building high-performance, concurrent, and scalable backend services using **Go (Golang)** in 2024/2025. It emphasizes idiomatic concurrency, resource safety, and strict Context API propagation.

## 🏗️ Core Architectural Dogmas

### 1. "Share Memory By Communicating"
*   **Dogma:** Do not communicate by sharing memory (Mutexes over shared variables); instead, share memory by communicating (Channels).
*   **Rule:** Use Channels to pass ownership of data between Goroutines securely. While `sync.Mutex` has its place for simple struct state protection, orchestrating complex workflows MUST rely on Channels to prevent race conditions and deadlocks.

### 2. The Context API (`context.Context`)
*   **Dogma:** The `context` package is mandatory for cancellation, timeouts, and request-scoped values across API boundaries and Goroutines.
*   **Rule:** `ctx context.Context` MUST always be the **first parameter** of any function that performs I/O, network requests, or spawns Goroutines.
*   **Rule:** NEVER store `context.Context` inside a struct type. It must flow explicitly through function arguments.
*   **Rule:** ALWAYS call the `cancel` function (using `defer cancel()`) returned by `context.WithCancel`, `WithTimeout`, or `WithDeadline` to prevent Goroutine leaks.

```go
// CERTO: Idiomatic Context Propagation and Cancellation
func FetchUser(ctx context.Context, id string) (*User, error) {
    req, err := http.NewRequestWithContext(ctx, "GET", "/users/"+id, nil)
    if err != nil {
        return nil, err
    }
    
    // The HTTP client will automatically abort if ctx.Done() is triggered
    res, err := http.DefaultClient.Do(req)
    // ... handling
}
```

### 3. Concurrency Patterns (Worker Pools & Fan-Out/Fan-In)
*   **Dogma:** Do not spawn unbounded Goroutines for incoming tasks (e.g., launching a Goroutine for every item in a 1,000,000 item slice). This will exhaust memory or database connection pools.
*   **Rule:** Implement **Worker Pools**. Spawn a fixed number of Goroutine workers (e.g., `runtime.NumCPU()`) that listen to a shared buffered Task Channel.
*   **Rule:** Use `sync.WaitGroup` to orchestrate exactly when a Fan-Out job is considered fully completed before closing the result channel.

## ⚙️ Execution and Operations

### 1. Channel Mechanics
*   **Dogma:** A sender should close the channel, never the receiver. Closing a channel signals that no more values will be sent.
*   **Rule:** Use the `select` statement to handle multiple channels non-blockingly, and ALWAYS include a `time.After` or `ctx.Done()` case in long-running `select` blocks to prevent deadlocks.
*   **Rule:** Use Unbuffered channels for exact synchronization (handshake). Use Buffered channels strictly for throughput optimization when producers are bursty.

### 2. Error Handling
*   **Dogma:** Errors are values. Inspect them explicitly.
*   **Rule:** In concurrent applications, use an `errgroup.Group` (from `golang.org/x/sync/errgroup`) to manage multiple Goroutines and intuitively capture the first error that occurs, which automatically cancels the context for the remaining parallel tasks.

## 🚨 Anti-Patterns (DO NOT DO THIS)

*   ❌ **NEVER** launch a Goroutine without a clear exit condition. If a Goroutine waits on a channel that is never written to or closed, it will leak memory permanently. ALWAYS pipe a `ctx.Done()` channel into every Goroutine's `select` statement.
*   ❌ **NEVER** use `time.Sleep()` to coordinate Goroutines. Use Channels or `sync.WaitGroup` for deterministic synchronization.
*   ❌ **NEVER** use `context.WithValue` to pass optional arguments, database connections, or core business logic data. Use it ONLY for cross-cutting tracing IDs, Auth Tokens, or strictly Request-Scoped metadata. Use custom unexported types as context keys to prevent collisions.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

