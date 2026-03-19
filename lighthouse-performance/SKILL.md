---
name: Lighthouse Performance Audit
description: Validate, measure, and optimize web application performance using Lighthouse metrics (LCP, CLS, INP), bundle analysis, code splitting strategies, image optimization, and Core Web Vitals monitoring.
---

# Lighthouse Performance — Core Web Vitals, Bundle & Optimization

## 1. Propósito

Auditar e otimizar performance de aplicações web usando métricas Lighthouse e Core Web Vitals. Cobre LCP, CLS, INP, bundle analysis, code splitting, lazy loading e monitoramento contínuo.

## 2. Dogmas Arquiteturais

### Performance Budget

**SEMPRE** definir budgets: Bundle initial < 200KB gzip, LCP < 2.5s, INP < 200ms, CLS < 0.1.

### Measure First

**NUNCA** otimizar sem medir. Rodar Lighthouse ANTES e DEPOIS de cada mudança.

### Critical Path

**SEMPRE** otimizar o critical rendering path primeiro: CSS above-the-fold, fonts, hero images.

## 3. Core Web Vitals

| Métrica | O que mede | Bom | Ruim | Como otimizar |
|---------|-----------|-----|------|---------------|
| **LCP** | Largest Contentful Paint — tempo até o maior elemento visível | < 2.5s | > 4.0s | Preload hero image, CSS inline, server-side rendering |
| **INP** | Interaction to Next Paint — responsividade | < 200ms | > 500ms | Evitar main thread blocking, web workers, code splitting |
| **CLS** | Cumulative Layout Shift — estabilidade visual | < 0.1 | > 0.25 | Dimensões explícitas em images/ads, font-display swap |

## 4. Patterns de Otimização

### 4.1 Code Splitting

```typescript
// CERTO — Lazy load por rota
import { lazy, Suspense } from "react";

const DashboardBuilder = lazy(() => import("./dashboard-builder"));
const Analytics = lazy(() => import("./analytics"));

function App() {
  return (
    <Suspense fallback={<PageSkeleton />}>
      <Routes>
        <Route path="/builder" element={<DashboardBuilder />} />
        <Route path="/analytics" element={<Analytics />} />
      </Routes>
    </Suspense>
  );
}
```

```typescript
// ERRADO — Import síncrono de componente pesado
import { DashboardBuilder } from "./dashboard-builder";  // 150KB no bundle inicial
```

### 4.2 Image Optimization

```tsx
// CERTO — next/image com dimensões explícitas (evita CLS)
import Image from "next/image";

<Image
  src="/hero.webp"
  alt="Hero"
  width={1200}
  height={600}
  priority            // LCP: preload
  sizes="100vw"
  className="w-full h-auto"
/>
```

```html
<!-- ERRADO — img sem dimensões = CLS -->
<img src="/hero.png" alt="Hero" />
<!-- Sem width/height, layout shift quando carrega -->
```

### 4.3 Font Loading

```css
/* CERTO — Font display swap evita FOIT */
@font-face {
  font-family: "Inter";
  src: url("/fonts/inter.woff2") format("woff2");
  font-display: swap;
  font-weight: 100 900;
}
```

```html
<!-- CERTO — Preload fontes críticas -->
<link rel="preload" href="/fonts/inter.woff2" as="font" type="font/woff2" crossorigin />
```

### 4.4 Bundle Analysis

```bash
# Next.js bundle analyzer
npm install @next/bundle-analyzer
```

```javascript
// next.config.js
const withBundleAnalyzer = require("@next/bundle-analyzer")({
  enabled: process.env.ANALYZE === "true",
});
module.exports = withBundleAnalyzer({ /* config */ });
```

```bash
# Rodar análise
ANALYZE=true npm run build
```

### 4.5 Tree Shaking

```typescript
// CERTO — Named imports (tree-shakeable)
import { format, parseISO } from "date-fns";
import { Shield, Users } from "lucide-react";
```

```typescript
// ERRADO — Importação do pacote inteiro
import _ from "lodash";          // 70KB+
import * as Icons from "lucide-react";  // Todos os ícones
```

## 5. Lighthouse CLI

```bash
# Rodar Lighthouse localmente
npx lighthouse http://localhost:3000 --output=json --output-path=./lighthouse-report.json

# Com preset mobile
npx lighthouse http://localhost:3000 --preset=perf --form-factor=mobile

# CI — budget enforcement
npx lighthouse http://localhost:3000 --budget-path=./budget.json
```

```json
// budget.json
[{
  "path": "/*",
  "resourceSizes": [
    { "resourceType": "script", "budget": 200 },
    { "resourceType": "stylesheet", "budget": 50 },
    { "resourceType": "image", "budget": 300 }
  ],
  "timings": [
    { "metric": "largest-contentful-paint", "budget": 2500 },
    { "metric": "cumulative-layout-shift", "budget": 0.1 }
  ]
}]
```

## 6. Checklist de Auditoria

- [ ] Bundle initial < 200KB gzip
- [ ] LCP < 2.5s (mobile e desktop)
- [ ] INP < 200ms
- [ ] CLS < 0.1
- [ ] Hero image com `priority` e dimensões explícitas
- [ ] Fontes com `font-display: swap` e preload
- [ ] Code splitting por rota (`React.lazy` ou `next/dynamic`)
- [ ] Named imports para tree shaking
- [ ] Sem `lodash` completo — usar `lodash-es` ou funções individuais
- [ ] `next/image` em todas as imagens
- [ ] Sem inline scripts bloqueantes
- [ ] CSS crítico inline / preloaded

## 7. Zero-Trust

- **NUNCA** ignorar warnings de Lighthouse — cada um é uma oportunidade.
- **NUNCA** usar `import *` de bibliotecas grandes.
- **NUNCA** colocar componentes pesados (charts, editors) no bundle inicial.
- **SEMPRE** medir antes e depois de otimizações.
- **SEMPRE** testar em throttled network (3G) e CPU (4x slowdown).

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

