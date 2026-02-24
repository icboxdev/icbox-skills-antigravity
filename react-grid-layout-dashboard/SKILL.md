---
name: react-grid-layout-dashboard
description: Architect, generate, and validate dashboard builders using react-grid-layout v2 with React/Next.js. Covers responsive grid, external drag-drop, widget registry, resize handles, design/static modes, and layout persistence.
---

# React Grid Layout v2 — Dashboard Builder Skill

## Context

`react-grid-layout` v2 is a complete TypeScript rewrite with ESM/CJS dual builds.
**v2 breaks the v1 API** — it replaces flat props with composable config objects
and the `WidthProvider` HOC with the `useContainerWidth` hook.

Stack: React 18+, Next.js 14+/16+ (App Router), TypeScript strict mode.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│  Dashboard Builder Page                                 │
│  ┌──────────┐  ┌────────────────────────────────────┐   │
│  │ Sidebar  │  │         Grid Area                   │   │
│  │          │  │  ┌──────┐ ┌──────┐ ┌──────┐        │   │
│  │ Widget   │  │  │Widget│ │Widget│ │Widget│        │   │
│  │ Palette  │──>  │  KPI │ │Chart │ │Prev. │        │   │
│  │          │  │  └──────┘ └──────┘ └──────┘        │   │
│  │ Drag or  │  │  ┌──────────────┐ ┌──────┐        │   │
│  │ Click    │  │  │   Widget     │ │Widget│        │   │
│  │          │  │  │  (resized)   │ │      │        │   │
│  └──────────┘  │  └──────────────┘ └──────┘        │   │
│                └────────────────────────────────────┘   │
│  Toolbar: [Save] [Reset] [Preview/Design] [Back]        │
└─────────────────────────────────────────────────────────┘
```

---

## Dogmas (MUST FOLLOW)

### 1. Use v2 API — NEVER use v1 flat props

```tsx
// ✅ CERTO — v2 composable config objects
<Responsive
  width={width}
  layouts={layouts}
  gridConfig={{ rowHeight: 60 }}
  dragConfig={{ enabled: true, handle: ".drag-handle" }}
  resizeConfig={{ enabled: true }}
  dropConfig={{
    enabled: true,
    defaultItem: { w: 6, h: 4 },
  }}
  onDrop={handleDrop}
  onDropDragOver={handleDropDragOver}
  onLayoutChange={handleLayoutChange}
/>

// ❌ ERRADO — v1 flat props (don't exist in v2 ESM)
<Responsive
  isDraggable={true}
  isResizable={true}
  isDroppable={true}
  draggableHandle=".drag-handle"
  droppingItem={{ i: "__dropping-elem__", w: 6, h: 4 }}
/>
```

### 2. Use `useContainerWidth` hook — NEVER use `WidthProvider`

```tsx
// ✅ CERTO — v2 hook
import { Responsive, useContainerWidth } from "react-grid-layout";

function MyGrid() {
  const { width, containerRef, mounted } = useContainerWidth();

  return (
    <div ref={containerRef}>
      {mounted && (
        <Responsive width={width} layouts={layouts}>
          {children}
        </Responsive>
      )}
    </div>
  );
}

// ❌ ERRADO — WidthProvider doesn't exist in v2 ESM
import { WidthProvider, Responsive } from "react-grid-layout";
const Grid = WidthProvider(Responsive);
```

### 3. Guard rendering with `mounted`

The grid MUST NOT render before `mounted` is true. Without this, SSR and
Turbopack will fail because the container width is unknown.

```tsx
// ✅ CERTO
const { width, containerRef, mounted } = useContainerWidth();

return (
  <div ref={containerRef}>
    {mounted && <Responsive width={width} ... />}
  </div>
);

// ❌ ERRADO — renders before width is known
return <Responsive width={containerWidth} ... />;
```

### 4. External drop uses `dropConfig` object

```tsx
// ✅ CERTO — v2 external drop
<Responsive
  dropConfig={{
    enabled: true,
    defaultItem: { w: 6, h: 4 },
  }}
  onDrop={(layout, item, event) => {
    const data = (event as DragEvent).dataTransfer?.getData("text/plain");
    if (!item || !data) return;
    const id = `w${idCounter.current++}`;
    setLayout([
      ...layout.filter(l => l.i !== "__dropping-elem__"),
      { ...item, i: id },
    ]);
  }}
  onDropDragOver={(e) => {
    return { w: 6, h: 4 }; // dimensions of placeholder
  }}
/>

// Sidebar item must set dataTransfer:
<div
  draggable
  onDragStart={(e) => {
    e.dataTransfer.setData("text/plain", widgetType);
    e.dataTransfer.effectAllowed = "copy";
  }}
/>
```

### 5. Drag handle goes in `dragConfig`

```tsx
// ✅ CERTO
dragConfig={{ enabled: designMode, handle: ".drag-handle" }}

// Inside each grid item:
<div className="drag-handle" style={{ cursor: "grab" }}>
  <GripVertical size={12} />
</div>

// ❌ ERRADO — flat prop
draggableHandle=".drag-handle"
```

### 6. Responsive layout callbacks use `(layout, allLayouts)` signature

```tsx
// ✅ CERTO — Responsive onLayoutChange
const handleLayoutChange = useCallback(
  (currentLayout: Layout[], allLayouts: Record<string, Layout[]>) => {
    const cleaned: Layouts = {};
    for (const [bp, lay] of Object.entries(allLayouts)) {
      cleaned[bp] = lay.filter(l => l.i !== "__dropping-elem__");
    }
    setLayouts(cleaned);
  },
  [],
);

// ❌ ERRADO — wrong signature
const handleLayoutChange = (layout: Layout[]) => { ... };
```

---

## Imports (ESM v2)

```tsx
// Components
import {
  Responsive, // ResponsiveGridLayout component
  GridLayout, // Basic GridLayout (non-responsive)
  GridItem, // Individual grid item (rarely used directly)
} from "react-grid-layout";

// Hooks
import {
  useContainerWidth, // Width measurement via ResizeObserver
  useGridLayout, // Headless grid layout hook
  useResponsiveLayout, // Headless responsive layout hook
} from "react-grid-layout";

// CSS — MUST import both
import "react-grid-layout/css/styles.css";
import "react-resizable/css/styles.css";
```

---

## Complete Dashboard Builder Template

```tsx
"use client";

import {
  useState,
  useCallback,
  useRef,
  useEffect,
  type DragEvent,
} from "react";
import { Responsive, useContainerWidth } from "react-grid-layout";
import "react-grid-layout/css/styles.css";
import "react-resizable/css/styles.css";
import "./dashboard-grid.css";

// ─── Types ───────────────────────────────────────────────
type WidgetType = "kpi" | "chart" | "preview";

interface WidgetDef {
  type: WidgetType;
  label: string;
  icon: React.ComponentType;
  defaultW: number;
  defaultH: number;
  minW: number;
  minH: number;
}

interface DashboardItem {
  id: string;
  widgetType: WidgetType;
  spaceId: string | null;
}

interface Layouts {
  [breakpoint: string]: Array<{
    i: string;
    x: number;
    y: number;
    w: number;
    h: number;
    minW?: number;
    minH?: number;
  }>;
}

// ─── Widget Registry ─────────────────────────────────────
const widgetRegistry: WidgetDef[] = [
  {
    type: "kpi",
    label: "KPIs",
    icon: Activity,
    defaultW: 6,
    defaultH: 3,
    minW: 3,
    minH: 2,
  },
  {
    type: "chart",
    label: "Chart",
    icon: BarChart3,
    defaultW: 6,
    defaultH: 4,
    minW: 4,
    minH: 3,
  },
  {
    type: "preview",
    label: "Preview",
    icon: MonitorPlay,
    defaultW: 6,
    defaultH: 4,
    minW: 3,
    minH: 2,
  },
];

// ─── Builder Component ───────────────────────────────────
export default function DashboardBuilder() {
  const [items, setItems] = useState<DashboardItem[]>([]);
  const [layouts, setLayouts] = useState<Layouts>({ lg: [] });
  const [designMode, setDesignMode] = useState(true);

  const { width, containerRef, mounted } = useContainerWidth();
  const idCounter = useRef(1);

  // ─── Layout Change ────────────────────────────────────
  const handleLayoutChange = useCallback(
    (_layout: unknown, allLayouts: Record<string, unknown[]>) => {
      const cleaned: Layouts = {};
      for (const [bp, lay] of Object.entries(allLayouts)) {
        cleaned[bp] = (lay as Layouts["lg"]).filter(
          (l) => l.i !== "__dropping-elem__",
        );
      }
      setLayouts(cleaned);
    },
    [],
  );

  // ─── Add Widget (click) ───────────────────────────────
  const addWidget = useCallback((widgetType: WidgetType) => {
    const id = `w${idCounter.current++}`;
    const def = widgetRegistry.find((w) => w.type === widgetType)!;
    setItems((prev) => [...prev, { id, widgetType, spaceId: null }]);
    setLayouts((prev) => ({
      ...prev,
      lg: [
        ...(prev.lg || []),
        {
          i: id,
          x: 0,
          y: Infinity,
          w: def.defaultW,
          h: def.defaultH,
          minW: def.minW,
          minH: def.minH,
        },
      ],
    }));
  }, []);

  // ─── External Drop ───────────────────────────────────
  const handleDrop = useCallback(
    (layout: Layouts["lg"], item: Layouts["lg"][0] | undefined, e: Event) => {
      const data = (e as unknown as globalThis.DragEvent).dataTransfer?.getData(
        "text/plain",
      ) as WidgetType;
      if (!data || !item) return;
      const def = widgetRegistry.find((w) => w.type === data);
      if (!def) return;

      const id = `w${idCounter.current++}`;
      setItems((prev) => [...prev, { id, widgetType: data, spaceId: null }]);
      setLayouts((prev) => ({
        ...prev,
        lg: [
          ...layout.filter((l) => l.i !== "__dropping-elem__"),
          { ...item, i: id, minW: def.minW, minH: def.minH },
        ],
      }));
    },
    [],
  );

  // ─── Remove Widget ────────────────────────────────────
  const removeWidget = useCallback((id: string) => {
    setItems((prev) => prev.filter((i) => i.id !== id));
    setLayouts((prev) => {
      const next: Layouts = {};
      for (const [bp, lay] of Object.entries(prev)) {
        next[bp] = lay.filter((l) => l.i !== id);
      }
      return next;
    });
  }, []);

  return (
    <div className="flex">
      {/* Sidebar */}
      {designMode && (
        <aside className="w-56 border-r">
          {widgetRegistry.map((def) => (
            <div
              key={def.type}
              draggable
              onDragStart={(e: DragEvent<HTMLDivElement>) => {
                e.dataTransfer.setData("text/plain", def.type);
                e.dataTransfer.effectAllowed = "copy";
              }}
              onClick={() => addWidget(def.type)}
              className="p-3 cursor-grab active:cursor-grabbing"
            >
              {def.label}
            </div>
          ))}
        </aside>
      )}

      {/* Grid */}
      <div ref={containerRef} className="flex-1">
        {mounted && items.length > 0 && (
          <Responsive
            width={width}
            layouts={layouts}
            breakpoints={{ lg: 1200, md: 996, sm: 768, xs: 480, xxs: 0 }}
            cols={{ lg: 12, md: 10, sm: 6, xs: 4, xxs: 2 }}
            gridConfig={{ rowHeight: 60 }}
            dragConfig={{
              enabled: designMode,
              handle: ".drag-handle",
            }}
            resizeConfig={{ enabled: designMode }}
            dropConfig={{
              enabled: designMode,
              defaultItem: { w: 6, h: 4 },
            }}
            compactType="vertical"
            onLayoutChange={handleLayoutChange}
            onDrop={handleDrop}
            onDropDragOver={() => ({ w: 6, h: 4 })}
          >
            {items.map((item) => (
              <div key={item.id}>
                {designMode && (
                  <div className="drag-handle" style={{ cursor: "grab" }}>
                    ⠿
                  </div>
                )}
                <div>{item.widgetType}</div>
              </div>
            ))}
          </Responsive>
        )}
      </div>
    </div>
  );
}
```

---

## CSS Override File (`dashboard-grid.css`)

```css
/* Card borders for grid items */
.react-grid-item > div:first-child {
  position: relative;
  height: 100%;
  border-radius: 0.75rem;
  border: 1px solid hsl(var(--border) / 0.5);
  background: hsl(var(--card));
}

/* Hover controls */
.react-grid-item:hover .grid-item-controls {
  opacity: 1 !important;
}

/* Resize handle */
.react-grid-item > .react-resizable-handle::after {
  border-right-color: hsl(var(--primary)) !important;
  border-bottom-color: hsl(var(--primary)) !important;
  opacity: 0.4;
  transition: opacity 0.2s;
}
.react-grid-item:hover > .react-resizable-handle::after {
  opacity: 1;
}

/* Drag placeholder */
.react-grid-item.react-grid-placeholder {
  background: hsl(var(--primary) / 0.1) !important;
  border: 2px dashed hsl(var(--primary) / 0.3);
  border-radius: 0.75rem;
  opacity: 1 !important;
}

/* Dragging shadow */
.react-grid-item.react-draggable-dragging {
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.4);
  opacity: 0.85;
}
```

---

## Config Object Reference

### `gridConfig`

```typescript
interface GridConfig {
  cols: number; // default: 12
  rowHeight: number; // default: 150
  maxRows: number; // default: Infinity
  margin: [number, number]; // default: [10, 10]
  containerPadding: [number, number] | null; // default: margin
}
```

### `dragConfig`

```typescript
interface DragConfig {
  enabled: boolean; // default: true
  handle: string; // CSS selector, e.g. ".drag-handle"
  cancel: string; // CSS selector for cancel areas
  allowOverlap: boolean; // default: false
}
```

### `resizeConfig`

```typescript
interface ResizeConfig {
  enabled: boolean; // default: true
  handles: ResizeHandle[]; // default: ["se"]
}
```

### `dropConfig`

```typescript
interface DropConfig {
  enabled: boolean; // default: false — MUST set true for external drop
  defaultItem: {
    w: number; // default width
    h: number; // default height
  };
  onDragOver?: (e: DragEvent) => { w?: number; h?: number } | false | void;
}
```

---

## Persistence Pattern

```typescript
interface DashboardConfig {
  items: DashboardItem[]; // Widget metadata (type, bound space, etc.)
  layouts: Layouts; // Grid positions per breakpoint
}

// Save to backend
async function save(workspaceId: string, config: DashboardConfig) {
  await api.updateWorkspace(workspaceId, {
    dashboardConfig: config,
  });
}

// Load on mount
useEffect(() => {
  async function load() {
    const ws = await api.getWorkspace(workspaceId);
    if (ws.dashboardConfig) {
      setItems(ws.dashboardConfig.items);
      setLayouts(ws.dashboardConfig.layouts);
    }
  }
  load();
}, [workspaceId]);
```

---

## Design/Static Mode Pattern

```tsx
// Toggle between edit and preview
const [designMode, setDesignMode] = useState(true);

// Grid props change based on mode
dragConfig={{ enabled: designMode, handle: ".drag-handle" }}
resizeConfig={{ enabled: designMode }}
dropConfig={{ enabled: designMode, defaultItem: { w: 6, h: 4 } }}

// Sidebar only visible in design mode
{designMode && <Sidebar />}

// Edit controls only visible in design mode
{designMode && <RemoveButton />}
```

---

## Common Pitfalls

| Pitfall                           | Solution                                                           |
| --------------------------------- | ------------------------------------------------------------------ |
| `WidthProvider is not a function` | Use `useContainerWidth` hook, not `WidthProvider`                  |
| Drop from sidebar doesn't work    | Use `dropConfig: { enabled: true }`, not `isDroppable`             |
| Grid renders with 0 width         | Guard with `{mounted && <Grid />}`                                 |
| Turbopack build error on import   | ESM build doesn't have `WidthProvider` — use named imports from v2 |
| `draggableHandle` type error      | Use `dragConfig: { handle: ".class" }`, not flat prop              |
| Layout resets on re-render        | Persist layouts in state, use `useCallback` for handlers           |
| `__dropping-elem__` persists      | Filter it out in `onLayoutChange` and `onDrop`                     |

---

## Zero-Trust Checklist

Before shipping any dashboard builder code, verify:

- [ ] `useContainerWidth` hook with `containerRef` on wrapper div
- [ ] `mounted` guard before rendering `<Responsive>`
- [ ] `dropConfig.enabled = true` for external drop
- [ ] `e.dataTransfer.setData("text/plain", data)` on sidebar items
- [ ] Filter `__dropping-elem__` in both `onLayoutChange` and `onDrop`
- [ ] `dragConfig.handle` set if using drag handles
- [ ] CSS imports: both `react-grid-layout/css/styles.css` AND `react-resizable/css/styles.css`
- [ ] Layouts state uses `Layouts` type (object keyed by breakpoint)
- [ ] Save config includes both `items` (metadata) and `layouts` (positions)
