---
name: WebGL & React Three Fiber (R3F) Performance
description: Architect, generate, and optimize 3D web applications using WebGL, Three.js, and React Three Fiber (R3F). Enforces draw call minimization (InstancedMesh), memory management, useFrame mutation patterns, and shader performance best practices.
---

# 🧊 WebGL & React Three Fiber Mastery

This skill defines the architectural dogmas and absolute best practices for building High-Performance 3D web applications using **React Three Fiber (R3F)** and **Three.js**, ensuring 60fps even on mobile devices by strictly managing the CPU-to-GPU bridge.

## 🏗️ Core Architectural Dogmas

### 1. The React-to-Three.js Boundary
*   **Dogma:** React's render cycle (reconciliation) is too slow for 60fps 3D animations. You MUST bypass React state (`useState`) for per-frame 3D object updates.
*   **Rule:** For animations, always use the `useFrame` hook, access the Three.js object via a `useRef`, and **mutate the properties directly**.

```tsx
// CERTO: R3F Animation Pattern
function SpinningBox() {
  const meshRef = useRef<THREE.Mesh>(null);
  
  useFrame((state, delta) => {
    // Direct mutation, bypassing React reconciliation!
    if (meshRef.current) {
      meshRef.current.rotation.x += delta * 0.5;
    }
  });

  return <mesh ref={meshRef}><boxGeometry/></mesh>;
}

// ERRADO: DO NOT DO THIS
// const [rotation, setRotation] = useState(0); 
// useFrame(() => setRotation(r => r + 0.01)); // Triggers React render 60 times a second!
```

### 2. Draw Call Minimization (The Ultimate Bottleneck)
*   **Dogma:** The number of instructions sent from CPU to GPU (Draw Calls) will bottleneck your app before polygon count does. 1000 separate cubes = 1000 draw calls. 1000 instanced cubes = 1 draw call.
*   **Rule:** If you have multiple objects sharing the same Geometry and Material, you MUST use `THREE.InstancedMesh` (or Drei's `<Instances>`).
*   **Rule:** Use `BufferGeometryUtils.mergeBufferGeometries` to combine static, non-moving environments into a single mesh.

### 3. Memory & Object Re-creation
*   **Dogma:** Garbage collection pauses cause stuttering. Never instantiate new objects (`new THREE.Vector3()`, `new THREE.Color()`) inside the `useFrame` loop.
*   **Rule:** Declare reusable vectors outside the component or loop, and use `.copy()`, `.set()`, or `.lerp()` to mutate them in place.
*   **Rule:** Mount heavy assets once. Use `useLoader` or Drei's `useGLTF` to cache geometries/materials heavily, avoiding re-parsing GLTF blobs on component remounts.

## ⚙️ Rendering Strategy

### 1. On-Demand Rendering
*   **Dogma:** If your 3D scene is static (only rotates when the user drags), do NOT waste battery calculating frames 60 times a second.
*   **Rule:** Set `<Canvas frameloop="demand">`. R3F will automatically render a frame only when React props change or when you manually call `invalidate()` (often bound to `OrbitControls`).

### 2. Shader Optimization
*   **Dogma:** Custom raw shaders (`ShaderMaterial`) should be optimized mathematically. Avoid branching (`if`/`else`) inside GLSL fragment shaders if possible; use math `step()`, `smoothstep()`, or `mix()`.
*   **Rule:** Pre-calculate complex lighting / baked shadows via Blender (Texture Baking) instead of calculating real-time dynamic shadows (`castShadow={true}`) for non-moving objects.

## 🚨 Anti-Patterns (DO NOT DO THIS)

*   ❌ **NEVER** place multiple `<Canvas>` elements on the same DOM page. Each spawns a heavy isolated WebGL context. Use a single `<Canvas>` fixed to the background and render R3F `View` components tracked to HTML DOM elements (using `@react-three/drei`'s `View`).
*   ❌ **NEVER** use `MeshStandardMaterial` arbitrarily if you don't need physically based lighting. If you just need a flat color, use `MeshBasicMaterial`. It skips lighting math entirely.
*   ❌ **NEVER** use large, uncompressed textures. Always compress UI textures to `.webp` or `.ktx2` (Basis Universal) before loading them into WebGL to save GPU VRAM.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

