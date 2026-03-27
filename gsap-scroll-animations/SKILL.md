---
name: GSAP & Scroll Animations
description: Architect, generate, and optimize complex scroll-driven animations using GSAP and ScrollTrigger in React/Next.js. Enforces the useGSAP hook, GPU-accelerated property targeting, strict React Server Components (RSC) isolation, and timeline orchestration.
---

# 🪄 GSAP & ScrollTrigger Mastery in React/Next.js

This skill defines the architectural dogmas and absolute best practices for building high-performance, complex, scroll-driven animations (Awwwards-level) using **GSAP** and **ScrollTrigger**, specifically adapted for **React** and **Next.js App Router (RSC)**.

## 🏗️ Core Architectural Dogmas

### 1. The `@gsap/react` `useGSAP()` Hook
*   **Dogma:** NEVER use a standard React `useEffect` with manual cleanup for GSAP animations anymore. It causes memory leaks on Fast Refresh and double-firing in Strict Mode.
*   **Rule:** You MUST use the `useGSAP` hook from `@gsap/react`. It automatically handles context scoping, revert/cleanup on unmount, and is uniquely tailored for React's lifecycle.

```tsx
// CERTO: Next.js Client Component GSAP pattern
"use client";
import gsap from "gsap";
import { useGSAP } from "@gsap/react";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { useRef } from "react";

gsap.registerPlugin(ScrollTrigger);

export function AnimatedSection() {
  const container = useRef(null);

  useGSAP(() => {
    // Scoped queries: selects elements ONLY inside 'container'
    gsap.from(".box", { 
      scrollTrigger: { trigger: container.current, start: "top center" },
      y: 100, 
      opacity: 0, 
      stagger: 0.1 
    });
  }, { scope: container }); // Scope is critical for component isolation!

  return (
    <div ref={container} className="h-screen">
       <div className="box">Box 1</div>
       <div className="box">Box 2</div>
    </div>
  );
}
```

### 2. Client Boundary Isolation (Next.js App Router)
*   **Dogma:** Animations require DOM access. They CANNOT run on the server.
*   **Rule:** Isolate GSAP logic tightly. Do not mark an entire page as `"use client"`. Create a very specific wrapper component (e.g., `<ScrollFadeIn>`) marked as `"use client"` that wraps Server Components passes as `children`.

## ⚙️ Performance Strategy

### 1. GPU Acceleration (Transform & Opacity Only)
*   **Dogma:** You MUST NOT animate CSS properties that trigger Browser Reflows or Layout recalculations.
*   **Rule:** Only animate `transform` (`x`, `y`, `scale`, `rotation`) and `opacity`. 
*   **Anti-Pattern:** Never animate `width`, `height`, `top`, `left`, `margin`, or `padding` in GSAP. (Substitute `margin-top` animation with `y` translation).
*   **Hint:** Apply `will-change: transform` via CSS to elements that contain heavy animations to prepare the browser rasterizer.

### 2. Responsive ScrollTrigger Contexts (`gsap.matchMedia`)
*   **Dogma:** Animations designed for Desktop often destroy Mobile performance or break layouts due to screen height constraints.
*   **Rule:** Use `gsap.matchMedia()` inside `useGSAP` to build conditional timelines. Completely kill heavy pinned ScrollTriggers on mobile (`max-width: 768px`) to ensure accessibility and performance.

### 3. Layout Shift Prevention (FOUC)
*   **Dogma:** Prevent the "Flash of Unstyled Content" where an element appears briefly before GSAP applies the initial state.
*   **Rule:** DO NOT set `opacity: 0` in CSS if the animation relies solely on JS, as users with JS disabled will see a blank page. Instead, use GSAP's `autoAlpha` feature (which toggles `visibility: hidden`) and apply initial states using `gsap.set()` at the very beginning of the `useGSAP` block.

## 🚨 Integration Checkpoints

*   **ScrollTrigger.refresh():** If your Next.js application dynamically loads images (`next/image` lazy loading) or fetches data that changes the DOM height drastically *after* the initial render, you MUST call `ScrollTrigger.refresh()` (usually in a `ResizeObserver` or image `onLoad`) so GSAP recalculates the trigger points.
*   **Timeline Orchestration:** Avoid chaining hundreds of independent `gsap.to()` calls. Group complex choreography into `gsap.timeline({ scrollTrigger: ... })` to control playback, reversal, and scrubbing uniformly.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

