---
name: Server-Driven UI (SDUI) Architecture
description: Architect, generate, and validate Server-Driven UI (SDUI) implementations for mobile and web. Enforces backend-controlled layout schemas (JSON/Protobuf), component registries, strict versioning, security diffing, and offline-fallback strategies.
---

# 📲 Server-Driven UI (SDUI) Architecture Mastery

This skill defines the architectural dogmas and absolute best practices for building dynamic, instantaneous-update frontend applications using **Server-Driven UI (SDUI)**, bypassing app store review cycles and enabling unparalleled cross-platform consistency.

## 🏗️ Core Architectural Dogmas

### 1. The Backend as the Layout Engine
*   **Dogma:** The server does not just return raw data (e.g., `{"name": "Ideilson", "balance": 100}`); it returns the exact UI composition instruction (e.g., `Render a Header, then a BalanceCard with data, then an ActionButton`).
*   **Rule:** The client (iOS, Android, React) acts purely as a "dumb" rendering engine (a Component Registry) that parses the JSON/Protobuf payload and maps it to native UI elements.

### 2. The Component Registry
*   **Dogma:** Clients MUST maintain a predefined registry of highly reusable, atomic visual components (e.g., `Text`, `Image`, `Button`, `Carousel`, `ProductCard`).
*   **Rule:** The JSON payload dictates the *arrangement* and *props* of these components, but the visual execution is native to the platform.

```json
// CERTO: Exemplo de Payload SDUI
{
  "screen": "home",
  "version": "1.2.0",
  "layout": {
    "type": "VerticalStack",
    "children": [
      {
        "type": "HeroBanner",
        "props": { "imageUrl": "https://...", "title": "Promoção" }
      },
      {
        "type": "ProductGrid",
        "props": { "endpoint": "/api/v1/user/recommendations" }
      }
    ]
  }
}
```

## ⚙️ Execution and Operations

### 1. Semantic Versioning & Capability Negotiation
*   **Dogma:** NEVER send a component to a client that it does not know how to render (e.g., sending a `VideoPlayer` component instruction to an old app version that lacks the native implementation).
*   **Rule:** The frontend MUST send its `AppVersion` and `SupportedComponentsList` in the request headers. The SDUI backend (BFF - Backend for Frontend) dynamically resolves the layout payload to match the capabilities of the requesting client.

### 2. Security and Payload Validation
*   **Dogma:** Treat UI layouts arriving from the server as Untrusted Input. 
*   **Rule:** The JSON Schema MUST be strongly typed and validated (e.g., using Zod on web, or Protobuf on mobile) before the rendering engine attempts to mount the tree.
*   **Rule:** Consider cryptographically signing the JSON payloads to prevent Man-in-the-Middle (MitM) attacks from altering the visual presentation of secure forms (e.g., changing a PIX copy-paste key in the UI payload).

### 3. Graceful Fallbacks & Caching
*   **Dogma:** SDUI inherently requires a network roundtrip to know *what* to render. This can impact perceived performance.
*   **Rule:** The client MUST cache the last known good layout for a screen. If the network is slow or offline, render the cached layout immediately with stale data, then perform background invalidation (ETag / Checksum checking). Compile "Base Layouts" into the binary for critical screens so they never load blank.

## 🚨 Anti-Patterns (DO NOT DO THIS)

*   ❌ **NEVER** use SDUI for applications that are primarily complex animations, games, or heavily reliant on device-native sensors (camera, gyroscope) where the state mutates 60 times per second. SDUI shines in content-heavy, marketing-driven, or form-heavy surfaces.
*   ❌ **NEVER** embed business logic directly into the UI payload (e.g., sending raw JavaScript strings to be `eval()`'d on the client). The payload must remain declarative (JSON/Protobuf). Action triggers should just dictate endpoints to hit or deep links to open.
*   ❌ **NEVER** attempt to build an SDUI framework from scratch if a robust Design System does not already exist. Without a standardized component library, SDUI becomes a maintenance nightmare.
