---
name: Micro-Frontends & Module Federation 2.0
description: Architect, scale, and stringently isolate Micro-Frontend (MFE) applications using Module Federation 2.0 and Rspack/Webpack. Enforces domain-driven splits, shared dependency optimization, distributed routing, and isolated deployment pipelines.
---

# 🧩 Micro-Frontends (MFE) & Module Federation 2.0 Mastery

This skill defines the architectural dogmas and absolute best practices for building scalable, independent, and natively federated frontend applications using **Module Federation 2.0 (MF2)** with High-Performance bundlers like **Rspack** (or Webpack 5).

## 🏗️ Architectural Dogmas (The "Why" and "How")

### 1. Domain-Driven Decomposition
*   **Dogma:** NEVER split Micro-Frontends by technical layer (e.g., "UI components app", "Logic app"). ALWAYS split by Business Domain (e.g., App "Checkout", App "Catalog", App "User Settings").
*   **Rule:** Each MFE MUST be owned by a single team and MUST be independently deployable without requiring synchronized releases with other MFEs.

### 2. Module Federation 2.0 & Rspack
*   **Dogma:** For new projects in 2024+, prioritize **Rspack** over Webpack. Rspack offers 5x-10x faster build times while maintaining Module Federation compatibility. Use `@module-federation/enhanced`.
*   **MF2 Features:** Leverage MF2's TypeScript type sharing (no more manual type imports across apps) and manifest-based remote discovery for dynamic environments.

### 3. Shared Dependencies Optimization
*   **Dogma:** Do NOT bundle massive frameworks (React, Vue, ReactDOM) inside every MFE.
*   **Rule:** Declare core frameworks and heavy libraries as `shared` in the Module Federation plugin config. Enforce `singleton: true` and `requiredVersion` to ensure only one instance of React exists in the browser to prevent context tearing and catastrophic rendering bugs.

```javascript
// CERTO: Rspack/Webpack Module Federation Plugin Config
new ModuleFederationPlugin({
  name: 'checkout_mfe',
  filename: 'remoteEntry.js',
  exposes: {
    './CheckoutPage': './src/pages/CheckoutPage',
  },
  shared: {
    react: { singleton: true, requiredVersion: '^18.0.0' },
    'react-dom': { singleton: true, requiredVersion: '^18.0.0' },
    '@tanstack/react-query': { singleton: true },
  },
});
```

## ⚙️ Communication and Global State

### 1. Zero-Coupling Cross-App Communication
*   **Dogma:** MFEs MUST NOT share a tight global state manager (like a single massive Redux store mapping across 5 apps).
*   **Rule:** If MFEs must communicate, use loosely coupled mechanisms:
    1.  **URL/Routing:** The host app pushes state to the URL, and the MFE reads it.
    2.  **Custom Events / Event Bus:** Dispatch `window.dispatchEvent(new CustomEvent('item-added'))`.
    3.  **Shared Hooks (via Registry):** Expose an auth hook from the Host app that other apps consume via Federation.

### 2. Uniform Design System
*   **Dogma:** Prevent "UI drift". All MFEs MUST consume UI components (Buttons, Inputs, Cards) from a unified, separately versioned Design System package (e.g., shadcn/ui configured in a monorepo workspace or private npm). Do not redefine raw CSS styles in generic MFEs.

## 🚨 Anti-Patterns (DO NOT DO THIS)

*   ❌ **NEVER** allow cyclical dependencies between MFEs (App A depends on App B, which depends on App A). This guarantees distributed deadlocks.
*   ❌ **NEVER** build "Micro-Frontends" if the team is small (e.g., 3 developers). The overhead of CI/CD, versioning, and Module Federation tooling will destroy productivity. MFE is an organizational scaling pattern, not just a technical one.
*   ❌ **NEVER** fetch `remoteEntry.js` files statically if environments change. Use MF2's dynamic manifest discovery (`manifest.json`) or a promise-based dynamic remote configuration for multi-tenant SaaS.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

