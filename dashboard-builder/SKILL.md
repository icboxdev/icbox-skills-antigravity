---
name: Dashboard Builder Engineering
description: Architect, generate, validate, and optimize interactive dashboard builders. Covers widget registry systems, react-grid-layout responsive grids, drag-and-drop composition, KPI cards and stat widgets, charting libraries (ECharts, Recharts, D3, Nivo), Canvas/WebGL rendering for large datasets, real-time WebSocket updates, layout persistence, filter/drill-down patterns, sparklines and micro-charts, visual hierarchy design, and performance optimization (lazy loading, virtualization, debouncing).
---

# Dashboard Builder Engineering — Diretrizes Senior+

## 0. Princípio Fundamental: Dashboard Como Produto

Um dashboard não é uma tela com gráficos soltos — é um **produto de decisão**:
- Todo widget DEVE responder: "que ação o usuário toma ao ver isso?"
- Widgets sem ação = desperdício de pixels. Remova-os.
- Dashboard congestionado é PIOR que dashboard vazio.
- **Regra dos 5 segundos**: se o usuário não entende o cenário em 5s, o dashboard falhou.

> ⚠️ **Crime Arquitetural**: Colocar 20 gráficos em uma tela sem hierarquia visual. Cada dashboard deve ter no máximo **5-7 widgets no viewport inicial** com drill-down para detalhes.

---

## 1. Arquitetura de Dashboard Builder

### 1.1 Hierarquia de Componentes

```
Dashboard Builder
├── ToolboxPanel           # Catálogo de widgets disponíveis
│   └── WidgetThumbnail    # Preview do widget arrastável
├── GridCanvas             # Área de grid com drag-and-drop
│   └── GridItem           # Container de widget no grid
│       └── WidgetRenderer # Renderiza widget por tipo (registry)
├── WidgetConfigPanel      # Painel de configuração do widget selecionado
│   ├── DataSourceConfig   # Seleção de fonte de dados
│   ├── AppearanceConfig   # Cores, labels, formato
│   └── FilterConfig       # Filtros locais do widget
├── GlobalFilters          # Filtros que afetam todos os widgets
│   ├── DateRangePicker    # Seletor de período
│   └── DimensionFilter    # Filtros por dimensão
└── LayoutPersistence      # Serialização e restore do layout
```

### 1.2 Widget Registry — Sistema Central

**Dogma**: Todo widget DEVE ser registrado em um Registry tipado. NUNCA renderize componentes com `switch/case` manuais.

```tsx
// CERTO: Widget Registry tipado com lazy loading
interface WidgetDefinition {
  type: string;
  label: string;
  icon: React.ComponentType;
  category: 'kpi' | 'chart' | 'table' | 'map' | 'custom';
  defaultSize: { w: number; h: number };
  minSize: { w: number; h: number };
  maxSize?: { w: number; h: number };
  component: React.LazyExoticComponent<React.ComponentType<WidgetProps>>;
  configSchema: z.ZodSchema;         // Zod schema para config do widget
  dataRequirements: DataRequirement;  // Quais dados o widget precisa
}

const WIDGET_REGISTRY: Record<string, WidgetDefinition> = {
  'kpi-card': {
    type: 'kpi-card',
    label: 'KPI Card',
    icon: TrendingUpIcon,
    category: 'kpi',
    defaultSize: { w: 3, h: 2 },
    minSize: { w: 2, h: 2 },
    component: lazy(() => import('./widgets/KpiCard')),
    configSchema: kpiCardSchema,
    dataRequirements: { metrics: 1, dimensions: 0 },
  },
  'line-chart': {
    type: 'line-chart',
    label: 'Line Chart',
    icon: LineChartIcon,
    category: 'chart',
    defaultSize: { w: 6, h: 4 },
    minSize: { w: 4, h: 3 },
    component: lazy(() => import('./widgets/LineChart')),
    configSchema: lineChartSchema,
    dataRequirements: { metrics: 1, dimensions: 1 },
  },
  // ... mais widgets
};

// Renderer genérico — NUNCA faça switch/case para renderizar widgets
function WidgetRenderer({ widget }: { widget: DashboardWidget }) {
  const definition = WIDGET_REGISTRY[widget.type];
  if (!definition) return <WidgetError message={`Widget "${widget.type}" não registrado`} />;

  const Component = definition.component;
  return (
    <Suspense fallback={<WidgetSkeleton size={definition.defaultSize} />}>
      <Component config={widget.config} data={widget.data} />
    </Suspense>
  );
}

// ERRADO: switch/case para cada tipo de widget — não escala
function BadRenderer({ widget }) {
  switch (widget.type) {
    case 'kpi': return <KpiCard {...widget} />;
    case 'bar': return <BarChart {...widget} />;
    // ... 50 cases depois...
    default: return null;  // falha silenciosa — NUNCA
  }
}
```

---

## 2. Grid Layout — react-grid-layout

### 2.1 Configuração Obrigatória

```tsx
// CERTO: ResponsiveGridLayout com breakpoints, persistência e collision prevention
import { Responsive, WidthProvider } from 'react-grid-layout';
import 'react-grid-layout/css/styles.css';
import 'react-resizable/css/styles.css';

const ResponsiveGridLayout = WidthProvider(Responsive);

const BREAKPOINTS = { lg: 1200, md: 996, sm: 768, xs: 480, xxs: 0 };
const COLS = { lg: 12, md: 10, sm: 6, xs: 4, xxs: 2 };

interface DashboardGridProps {
  widgets: DashboardWidget[];
  layouts: Layouts;
  isEditing: boolean;                  // modo design vs static
  onLayoutChange: (layouts: Layouts) => void;
}

function DashboardGrid({ widgets, layouts, isEditing, onLayoutChange }: DashboardGridProps) {
  return (
    <ResponsiveGridLayout
      layouts={layouts}
      breakpoints={BREAKPOINTS}
      cols={COLS}
      rowHeight={80}
      isDraggable={isEditing}          // arrastar SÓ no modo edit
      isResizable={isEditing}          // redimensionar SÓ no modo edit
      preventCollision={false}         // permitir compactação automática
      compactType="vertical"           // widgets fluem para cima
      onLayoutChange={(_, allLayouts) => onLayoutChange(allLayouts)}
      draggableHandle=".widget-drag-handle"  // handle explícito — não toda a superfície
      resizeHandles={['se']}           // apenas canto inferior direito
      margin={[16, 16]}               // gap consistente com design system
      containerPadding={[16, 16]}
    >
      {widgets.map((widget) => (
        <div
          key={widget.id}
          data-grid={{
            ...widget.gridLayout,
            minW: WIDGET_REGISTRY[widget.type]?.minSize.w ?? 2,
            minH: WIDGET_REGISTRY[widget.type]?.minSize.h ?? 2,
            static: !isEditing,
          }}
        >
          <WidgetWrapper widget={widget} isEditing={isEditing} />
        </div>
      ))}
    </ResponsiveGridLayout>
  );
}

// ERRADO: grid sem breakpoints, drag habilitado em produção
<ReactGridLayout isDraggable={true} cols={12}>  {/* drag sempre ligado é chaos UX */}
```

### 2.2 Layout Persistence — Serialização

```tsx
// CERTO: persistir layout tipado com Zod validation
const layoutSchema = z.object({
  id: z.string().uuid(),
  name: z.string().min(1).max(100),
  layouts: z.record(z.array(z.object({
    i: z.string(),
    x: z.number().int().nonnegative(),
    y: z.number().int().nonnegative(),
    w: z.number().int().positive(),
    h: z.number().int().positive(),
  }))),
  widgets: z.array(widgetSchema),
  updatedAt: z.string().datetime(),
});

// Salvar no backend como JSON — UUID do layout por tenant
async function saveDashboardLayout(dashboardId: string, layouts: Layouts): Promise<void> {
  const validated = layoutSchema.parse({ ...dashboard, layouts });
  await api.put(`/dashboards/${dashboardId}/layout`, validated);
}

// Restaurar ao carregar — SEMPRE validar dados do servidor
async function loadDashboardLayout(dashboardId: string): Promise<Dashboard> {
  const response = await api.get(`/dashboards/${dashboardId}`);
  return layoutSchema.parse(response.data);  // Parse falha = layout corrompido → usar default
}

// ERRADO: salvar em localStorage sem validação
localStorage.setItem('layout', JSON.stringify(layout));  // sem Zod = crash silencioso
```

### 2.3 Drag-and-Drop Externo (Toolbox → Grid)

```tsx
// CERTO: External drag do catálogo para o grid
import { useDrag } from 'react-dnd';

function WidgetThumbnail({ widgetType }: { widgetType: string }) {
  const definition = WIDGET_REGISTRY[widgetType];
  const [{ isDragging }, dragRef] = useDrag({
    type: 'WIDGET',
    item: { type: widgetType, ...definition.defaultSize },
    collect: (monitor) => ({ isDragging: monitor.isDragging() }),
  });

  return (
    <div ref={dragRef} className={cn('widget-thumbnail', isDragging && 'opacity-50')}>
      <definition.icon className="size-6" />
      <span>{definition.label}</span>
    </div>
  );
}

// No grid: interceptar drop e adicionar widget com posição calculada
function handleDrop(item: DragItem, position: { x: number; y: number }) {
  const newWidget: DashboardWidget = {
    id: crypto.randomUUID(),
    type: item.type,
    config: getDefaultConfig(item.type),
    gridLayout: { ...position, w: item.w, h: item.h },
  };
  addWidget(newWidget);
}
```

---

## 3. Widgets — Anatomia e Padrões

### 3.1 Widget Wrapper — Obrigatório Para Todos

```tsx
// CERTO: WidgetWrapper com estados obrigatórios (loading, error, empty, config)
interface WidgetWrapperProps {
  widget: DashboardWidget;
  isEditing: boolean;
}

function WidgetWrapper({ widget, isEditing }: WidgetWrapperProps) {
  const { data, isLoading, error, refetch } = useWidgetData(widget);

  return (
    <div className="widget-container group" role="region" aria-label={widget.config.title}>
      {/* Header — SEMPRE presente */}
      <div className="widget-header">
        {isEditing && (
          <div className="widget-drag-handle cursor-grab">
            <GripVerticalIcon className="size-4 text-muted-foreground" />
          </div>
        )}
        <h3 className="widget-title text-sm font-medium truncate">{widget.config.title}</h3>
        <div className="widget-actions opacity-0 group-hover:opacity-100 transition-opacity">
          {isEditing ? (
            <>
              <WidgetConfigButton widget={widget} />
              <WidgetDeleteButton widgetId={widget.id} />
            </>
          ) : (
            <>
              <WidgetRefreshButton onRefresh={refetch} />
              <WidgetExpandButton widget={widget} />
            </>
          )}
        </div>
      </div>

      {/* Content — 4 estados obrigatórios */}
      <div className="widget-content flex-1 overflow-hidden">
        {isLoading ? (
          <WidgetSkeleton type={widget.type} />     {/* skeleton, NUNCA spinner */}
        ) : error ? (
          <WidgetError error={error} onRetry={refetch} />
        ) : !data || data.length === 0 ? (
          <WidgetEmpty message="Sem dados para o período selecionado" />
        ) : (
          <Suspense fallback={<WidgetSkeleton type={widget.type} />}>
            <WidgetRenderer widget={{ ...widget, data }} />
          </Suspense>
        )}
      </div>
    </div>
  );
}

// ERRADO: widget sem estados de loading/error/empty
function BadWidget({ data }) {
  return <Chart data={data} />;  // crash se data === null, undefined, []
}
```

### 3.2 KPI Card — O Widget Mais Importante

```tsx
// CERTO: KPI Card com trend, comparação e sparkline
interface KpiCardProps {
  title: string;
  value: number;
  previousValue: number;
  format: 'currency' | 'number' | 'percentage';
  trendData?: number[];         // últimos 7-30 pontos para sparkline
  goal?: number;                // meta para progress bar
}

function KpiCard({ title, value, previousValue, format, trendData, goal }: KpiCardProps) {
  const change = ((value - previousValue) / previousValue) * 100;
  const isPositive = change > 0;
  const formatted = formatValue(value, format);

  return (
    <div className="kpi-card" role="figure" aria-label={`${title}: ${formatted}`}>
      <div className="kpi-header">
        <span className="text-xs text-muted-foreground uppercase tracking-wider">{title}</span>
      </div>

      <div className="kpi-value text-2xl font-bold tabular-nums">
        {formatted}
      </div>

      <div className="kpi-comparison flex items-center gap-1">
        <span className={cn(
          'text-xs font-medium',
          isPositive ? 'text-emerald-500' : 'text-red-500'
        )}>
          {isPositive ? '↑' : '↓'} {Math.abs(change).toFixed(1)}%
        </span>
        <span className="text-xs text-muted-foreground">vs período anterior</span>
      </div>

      {/* Sparkline inline — mostra tendência sem ocupar espaço */}
      {trendData && trendData.length > 2 && (
        <div className="kpi-sparkline h-8 mt-2" aria-hidden="true">
          <Sparkline data={trendData} color={isPositive ? '#10b981' : '#ef4444'} />
        </div>
      )}

      {/* Progress bar para meta */}
      {goal && (
        <div className="kpi-goal mt-2">
          <div className="flex justify-between text-xs text-muted-foreground mb-1">
            <span>Meta</span>
            <span>{Math.round((value / goal) * 100)}%</span>
          </div>
          <Progress value={(value / goal) * 100} className="h-1.5" />
        </div>
      )}
    </div>
  );
}

// ERRADO: KPI card sem comparação nem contexto
function BadKpi({ value }) {
  return <div className="text-2xl">{value}</div>;
  // sem título, sem trend, sem comparação — inútil para decisão
}
```

### 3.3 Sparkline Inline — Sem Biblioteca Externa

```tsx
// CERTO: sparkline leve com SVG puro (não importar ECharts para 20 pixels de gráfico)
interface SparklineProps {
  data: number[];
  color?: string;
  width?: number;
  height?: number;
}

function Sparkline({ data, color = '#3b82f6', width = 100, height = 24 }: SparklineProps) {
  if (data.length < 2) return null;

  const min = Math.min(...data);
  const max = Math.max(...data);
  const range = max - min || 1;

  const points = data.map((v, i) => {
    const x = (i / (data.length - 1)) * width;
    const y = height - ((v - min) / range) * height;
    return `${x},${y}`;
  }).join(' ');

  return (
    <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`} aria-hidden="true">
      <polyline
        points={points}
        fill="none"
        stroke={color}
        strokeWidth={1.5}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

// ERRADO: importar ECharts/Recharts para renderizar uma sparkline de 20px
import ReactECharts from 'echarts-for-react';  // 500KB+ para 20px de gráfico — NUNCA
```

---

## 4. Charting — Escolha de Biblioteca e Performance

### 4.1 Decisão de Biblioteca Por Caso

| Cenário | Biblioteca | Rendering | Motivo |
|---|---|---|---|
| Sparklines, indicadores inline | **SVG Puro** | SVG | Peso zero, sem dependência |
| Dashboards < 1k pontos | **Recharts** | SVG | API declarativa, fácil de usar |
| Dashboards 1k-100k pontos | **ECharts** | Canvas | Performance, interatividade built-in |
| Dashboards > 100k pontos | **Deck.gl / ECharts WebGL** | WebGL | GPU-accelerated, mapas 3D |
| Visualizações custom únicas | **D3.js + Visx** | SVG/Canvas | Controle total, sem limites |

**Regra absoluta**: NUNCA use SVG para renderizar > 5.000 elementos no DOM. A partir desse limiar, use **Canvas** (ECharts) ou **WebGL** (Deck.gl).

### 4.2 ECharts — Padrão para Dashboards de Produção

```tsx
// CERTO: ECharts com Canvas, responsive, e configuração tipada
import ReactECharts from 'echarts-for-react';
import type { EChartsOption } from 'echarts';

interface TimeSeriesChartProps {
  data: { date: string; value: number }[];
  title: string;
  format?: 'currency' | 'number';
}

const TimeSeriesChart = React.memo(function TimeSeriesChart({
  data, title, format = 'number'
}: TimeSeriesChartProps) {
  const option: EChartsOption = useMemo(() => ({
    tooltip: {
      trigger: 'axis',
      formatter: (params: CallbackDataParams[]) => {
        const point = params[0];
        return `${point.name}<br/>${formatValue(point.value as number, format)}`;
      },
    },
    grid: { left: 48, right: 16, top: 24, bottom: 32 },  // margens compactas
    xAxis: {
      type: 'category',
      data: data.map(d => d.date),
      axisLabel: { fontSize: 11, color: '#888' },
      axisLine: { lineStyle: { color: '#333' } },
    },
    yAxis: {
      type: 'value',
      axisLabel: {
        fontSize: 11,
        color: '#888',
        formatter: (v: number) => formatCompact(v, format),
      },
      splitLine: { lineStyle: { color: '#1a1a1d', type: 'dashed' } },
    },
    series: [{
      type: 'line',
      data: data.map(d => d.value),
      smooth: true,
      symbol: 'none',                // sem markers em time-series — poluem
      lineStyle: { width: 2 },
      areaStyle: {
        color: {
          type: 'linear',
          x: 0, y: 0, x2: 0, y2: 1,
          colorStops: [
            { offset: 0, color: 'rgba(56, 189, 248, 0.2)' },
            { offset: 1, color: 'rgba(56, 189, 248, 0.02)' },
          ],
        },
      },
    }],
    animation: true,
    animationDuration: 500,
    animationEasing: 'cubicOut',
  }), [data, format]);

  return (
    <ReactECharts
      option={option}
      style={{ height: '100%', width: '100%' }}
      opts={{ renderer: 'canvas' }}     // SEMPRE Canvas para performance
      notMerge={true}                    // re-render completo quando option muda
    />
  );
}, (prev, next) => prev.data === next.data && prev.format === next.format);

// ERRADO: ECharts sem memoizar option — recria em cada render
function BadChart({ data }) {
  return <ReactECharts option={{ /* inline object recriado a cada render */ }} />;
}
```

### 4.3 Rendering: SVG vs Canvas vs WebGL

```
Performance Matrix:
┌──────────────┬───────────┬───────────┬───────────┐
│ Data Points  │ SVG       │ Canvas    │ WebGL     │
├──────────────┼───────────┼───────────┼───────────┤
│ < 500        │ ✅ Ideal  │ OK        │ Overkill  │
│ 500-5,000    │ ⚠️ Lento  │ ✅ Ideal  │ OK        │
│ 5,000-100k   │ ❌ Crash  │ ✅ Ideal  │ ✅ Ideal  │
│ > 100k       │ ❌ Crash  │ ⚠️ Lento  │ ✅ Ideal  │
└──────────────┴───────────┴───────────┴───────────┘
```

**Regras**:
- Sparklines e KPIs → SVG inline (lightweight, accessible).
- Gráficos de dashboard padrão (bar, line, pie, area) → **Canvas** (ECharts).
- Mapas de calor, scatter > 10k pontos, geoespacial → **WebGL** (Deck.gl, ECharts GL).
- NUNCA renderize tabelas com > 500 linhas sem **virtualização** (`@tanstack/react-virtual`).

---

## 5. Performance — Regras Absolutas

### 5.1 Lazy Loading de Widgets

```tsx
// CERTO: cada widget é lazy-loaded individualmente
const WIDGET_REGISTRY = {
  'kpi-card': {
    component: lazy(() => import(/* webpackChunkName: "widget-kpi" */ './widgets/KpiCard')),
  },
  'bar-chart': {
    component: lazy(() => import(/* webpackChunkName: "widget-bar" */ './widgets/BarChart')),
  },
  'data-table': {
    component: lazy(() => import(/* webpackChunkName: "widget-table" */ './widgets/DataTable')),
  },
};

// ERRADO: importar todos os widgets no bundle inicial
import { KpiCard } from './widgets/KpiCard';      // 20KB
import { BarChart } from './widgets/BarChart';     // 150KB (ECharts)
import { DataTable } from './widgets/DataTable';   // 80KB (TanStack Table)
// Total: 250KB+ no initial bundle — NUNCA
```

### 5.2 Data Fetching Otimizado

```tsx
// CERTO: TanStack Query com staleTime para evitar re-fetches desnecessários
function useWidgetData(widget: DashboardWidget) {
  const globalFilters = useDashboardFilters();

  return useQuery({
    queryKey: ['widget-data', widget.id, widget.config, globalFilters],
    queryFn: () => fetchWidgetData(widget, globalFilters),
    staleTime: 5 * 60 * 1000,           // 5 min — evita refetch ao trocar de tab
    gcTime: 15 * 60 * 1000,             // 15 min no cache
    placeholderData: keepPreviousData,   // mantém dados anteriores durante refetch
    refetchOnWindowFocus: false,         // dashboard não precisa refetch a cada foco
    retry: 2,
  });
}

// CERTO: batch multiple widget data requests em uma única request
async function fetchDashboardData(
  widgets: DashboardWidget[],
  filters: DashboardFilters
): Promise<Record<string, WidgetData>> {
  // Uma request busca dados de TODOS os widgets — não N requests paralelas
  const response = await api.post('/api/dashboards/batch-query', {
    queries: widgets.map(w => ({
      widgetId: w.id,
      type: w.type,
      config: w.config,
      filters,
    })),
  });
  return response.data;
}

// ERRADO: cada widget faz sua própria request individual
// 10 widgets = 10 requests paralelas = thundering herd no backend
```

### 5.3 Real-Time Updates — WebSocket, Não Polling

```tsx
// CERTO: WebSocket com throttle para real-time sem flood de renders
function useRealtimeDashboard(dashboardId: string) {
  const queryClient = useQueryClient();

  useEffect(() => {
    const ws = new WebSocket(`wss://api/dashboards/${dashboardId}/live`);

    // Throttle: acumula updates e aplica no máximo 1x por segundo
    let pendingUpdates: Record<string, WidgetData> = {};
    let flushTimer: NodeJS.Timeout | null = null;

    ws.onmessage = (event) => {
      const update = JSON.parse(event.data) as { widgetId: string; data: WidgetData };
      pendingUpdates[update.widgetId] = update.data;

      if (!flushTimer) {
        flushTimer = setTimeout(() => {
          Object.entries(pendingUpdates).forEach(([widgetId, data]) => {
            queryClient.setQueryData(['widget-data', widgetId], data);
          });
          pendingUpdates = {};
          flushTimer = null;
        }, 1000);  // flush a cada 1s máximo
      }
    };

    return () => {
      ws.close();
      if (flushTimer) clearTimeout(flushTimer);
    };
  }, [dashboardId, queryClient]);
}

// ERRADO: polling para "real-time"
setInterval(() => {                    // 60 req/min por widget × 10 widgets = 600 req/min
  widgets.forEach(w => fetchData(w));  // POR USUÁRIO. 100 usuários = 60k req/min — EXPLOSION
}, 1000);
```

### 5.4 Debounce em Filtros

```tsx
// CERTO: debounce em filtros globais que afetam todos os widgets
function GlobalFilters() {
  const [filters, setFilters] = useState<FilterState>(defaultFilters);
  const debouncedFilters = useDebounce(filters, 300);  // espera 300ms antes de re-query

  // Apenas debouncedFilters é usado como queryKey — evita N requests durante digitação
  useEffect(() => {
    dashboardStore.setFilters(debouncedFilters);
  }, [debouncedFilters]);

  return (
    <div className="global-filters">
      <DateRangePicker
        value={filters.dateRange}
        onChange={(range) => setFilters(f => ({ ...f, dateRange: range }))}
        presets={DATE_PRESETS}  // Hoje, 7d, 30d, 90d, YTD, Custom — SEMPRE oferecer presets
      />
      <DimensionFilter
        value={filters.segment}
        options={segments}
        onChange={(v) => setFilters(f => ({ ...f, segment: v }))}
      />
    </div>
  );
}

// ERRADO: filtro sem debounce dispara request a cada keystroke
onChange={(v) => fetchAllWidgets(v)}  // 10 requests por segundo durante typing
```

---

## 6. Design e UX — Hierarquia Visual

### 6.1 Layout Pattern — F-Pattern

```
┌─────────────────── Global Filters (DateRange | Segment | Search) ──────────────┐
│                                                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐                       │
│  │ KPI Card │  │ KPI Card │  │ KPI Card │  │ KPI Card │   ← Topo: KPIs       │
│  │ Revenue  │  │ Users    │  │ Conv.    │  │ Churn    │      (métricas-chave) │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘                       │
│                                                                                 │
│  ┌────────────────────────────────┐  ┌──────────────────────┐                  │
│  │                                │  │                      │                  │
│  │    Time Series (principal)     │  │   Distribution Pie   │ ← Meio: análise  │
│  │    Revenue Over Time           │  │   Revenue by Channel │                  │
│  │                                │  │                      │                  │
│  └────────────────────────────────┘  └──────────────────────┘                  │
│                                                                                 │
│  ┌──────────────────────────────────────────────────────────┐                  │
│  │                                                          │                  │
│  │              Data Table (drill-down details)             │ ← Base: detalhes │
│  │                                                          │                  │
│  └──────────────────────────────────────────────────────────┘                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

**Dogma de Layout**:
1. **Topo** → KPI cards (4-5 max) com sparklines e comparação de período.
2. **Meio-esquerda** → Gráfico principal (time-series, maior widget).
3. **Meio-direita** → Distribuição ou breakdown (pie, donut, stacked bar).
4. **Base** → Tabela com drill-down para registros individuais.

### 6.2 Dark Mode — Padrão para Dashboards

```css
/* Design tokens para dashboard escuro */
:root {
  /* Backgrounds — hierarquia de profundidade */
  --dashboard-bg: #09090b;         /* fundo principal */
  --widget-bg: #111113;            /* fundo do widget */
  --widget-bg-hover: #1a1a1d;     /* hover/seleção */
  --widget-border: #27272a;        /* borda sutil */

  /* Text — hierarquia tipográfica */
  --text-primary: #fafafa;
  --text-secondary: #a1a1aa;
  --text-muted: #71717a;

  /* Chart palette — acessível em fundo escuro */
  --chart-1: #38bdf8;   /* sky-400 */
  --chart-2: #22d3ee;   /* cyan-400 */
  --chart-3: #a78bfa;   /* violet-400 */
  --chart-4: #f472b6;   /* pink-400 */
  --chart-5: #fbbf24;   /* amber-400 */
  --chart-6: #34d399;   /* emerald-400 */

  /* Semantic — trend colors */
  --trend-positive: #10b981;
  --trend-negative: #ef4444;
  --trend-neutral: #71717a;

  /* Grid */
  --grid-gap: 16px;
  --widget-radius: 12px;
  --widget-padding: 16px;
}

/* Widget card base */
.widget-container {
  background: var(--widget-bg);
  border: 1px solid var(--widget-border);
  border-radius: var(--widget-radius);
  padding: var(--widget-padding);
  display: flex;
  flex-direction: column;
  height: 100%;
  transition: border-color 150ms ease;
}

.widget-container:hover {
  border-color: color-mix(in srgb, var(--chart-1) 30%, transparent);
}

/* KPI value — usar tabular-nums para alinhamento de dígitos */
.kpi-value {
  font-variant-numeric: tabular-nums;
  letter-spacing: -0.02em;
}
```

### 6.3 Acessibilidade (WCAG 2.2 AA)

```tsx
// CERTO: acessibilidade obrigatória em todos os widgets
function AccessibleChart({ title, description, data, children }: AccessibleChartProps) {
  const tableId = useId();

  return (
    <figure role="figure" aria-labelledby={`chart-${tableId}`}>
      <figcaption id={`chart-${tableId}`} className="sr-only">
        {title}: {description}
      </figcaption>

      {/* Gráfico visual */}
      <div aria-hidden="true">
        {children}
      </div>

      {/* Tabela alternativa para screen readers + export */}
      <details className="mt-2">
        <summary className="text-xs text-muted-foreground cursor-pointer">
          Ver dados em tabela
        </summary>
        <table className="text-xs w-full mt-1">
          <thead>
            <tr>{Object.keys(data[0]).map(k => <th key={k}>{k}</th>)}</tr>
          </thead>
          <tbody>
            {data.map((row, i) => (
              <tr key={i}>{Object.values(row).map((v, j) => <td key={j}>{String(v)}</td>)}</tr>
            ))}
          </tbody>
        </table>
      </details>
    </figure>
  );
}

// Keyboard navigation para widgets no grid
function WidgetKeyboardNav({ widgets, activeWidgetId, onActivate }: WidgetNavProps) {
  const handleKeyDown = useCallback((e: KeyboardEvent) => {
    const currentIndex = widgets.findIndex(w => w.id === activeWidgetId);
    if (currentIndex === -1) return;

    switch (e.key) {
      case 'ArrowRight': onActivate(widgets[Math.min(currentIndex + 1, widgets.length - 1)].id); break;
      case 'ArrowLeft': onActivate(widgets[Math.max(currentIndex - 1, 0)].id); break;
      case 'Enter': openWidgetDetail(activeWidgetId); break;
    }
  }, [widgets, activeWidgetId, onActivate]);

  useEffect(() => {
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [handleKeyDown]);

  return null;
}
```

---

## 7. Modos do Dashboard — Design vs View

### 7.1 Dois Modos Distintos

```tsx
// CERTO: Dashboard tem dois modos claros com UX distinta
type DashboardMode = 'view' | 'edit';

function Dashboard({ dashboardId }: { dashboardId: string }) {
  const [mode, setMode] = useState<DashboardMode>('view');
  const { dashboard, updateLayout, addWidget, removeWidget } = useDashboard(dashboardId);

  return (
    <div className={cn('dashboard', mode === 'edit' && 'dashboard--editing')}>
      <DashboardHeader
        title={dashboard.name}
        mode={mode}
        onToggleMode={() => setMode(m => m === 'view' ? 'edit' : 'view')}
        onSave={() => { saveDashboard(dashboard); setMode('view'); }}
      />

      {mode === 'view' && <GlobalFilters />}
      {mode === 'edit' && <ToolboxPanel onAddWidget={addWidget} />}

      <DashboardGrid
        widgets={dashboard.widgets}
        layouts={dashboard.layouts}
        isEditing={mode === 'edit'}
        onLayoutChange={updateLayout}
      />
    </div>
  );
}
```

**Regras de Modo**:
- **View mode**: widgets são `static`, drag/resize desabilitados, filtros globais visíveis.
- **Edit mode**: widgets são draggable/resizable, toolbox aberto, filtros escondidos.
- NUNCA misture os dois — o usuário deve saber claramente se está editando ou visualizando.
- Salvar layout DEVE ser ação explícita (botão "Salvar"), NUNCA auto-save contínuo.

---

## 8. Estrutura de Projeto Dashboard

```
src/
├── features/dashboard/
│   ├── components/
│   │   ├── DashboardGrid.tsx           # Grid Layout principal
│   │   ├── DashboardHeader.tsx         # Título + Actions (Save, Edit, Share)
│   │   ├── GlobalFilters.tsx           # DateRange + Dimensões
│   │   ├── ToolboxPanel.tsx            # Painel de widgets disponíveis
│   │   ├── WidgetWrapper.tsx           # Container padrão (header, loading, error)
│   │   └── WidgetConfigPanel.tsx       # Config do widget selecionado
│   ├── widgets/
│   │   ├── registry.ts                 # WIDGET_REGISTRY central
│   │   ├── KpiCard.tsx                 # Lazy-loaded
│   │   ├── TimeSeriesChart.tsx         # Lazy-loaded
│   │   ├── BarChart.tsx                # Lazy-loaded
│   │   ├── PieChart.tsx                # Lazy-loaded
│   │   ├── DataTable.tsx               # Lazy-loaded
│   │   ├── Sparkline.tsx               # SVG puro (não lazy)
│   │   └── GeoMap.tsx                  # Lazy-loaded (WebGL heavy)
│   ├── hooks/
│   │   ├── useDashboard.ts            # State do dashboard (layout + widgets)
│   │   ├── useWidgetData.ts           # TanStack Query para dados do widget
│   │   ├── useDashboardFilters.ts     # Filtros globais (Zustand)
│   │   └── useRealtimeDashboard.ts    # WebSocket subscription
│   ├── services/
│   │   ├── dashboard.service.ts       # API calls (CRUD dashboard)
│   │   └── widget-data.service.ts     # API calls (batch data fetch)
│   ├── schemas/
│   │   ├── layout.schema.ts           # Zod: layout serialization
│   │   └── widget-config.schema.ts    # Zod: config por tipo de widget
│   └── types/
│       ├── dashboard.types.ts         # DashboardWidget, Layouts, FilterState
│       └── widget.types.ts            # WidgetDefinition, WidgetProps, DataRequirement
└── shared/
    ├── components/
    │   ├── DateRangePicker.tsx
    │   └── DimensionFilter.tsx
    └── utils/
        ├── format-value.ts            # Formatação de moeda, number, percentage
        └── format-compact.ts          # 1.2K, 3.4M, etc.
```

---

## 9. Checklist Senior+ — Dashboard Builder

Antes de entregar um dashboard builder para produção:

- [ ] **Widget Registry** — todo widget registrado com type, defaultSize, minSize e lazy import.
- [ ] **4 estados obrigatórios** — loading (skeleton), error (retry), empty (mensagem), data (widget).
- [ ] **Layout persistence** — layouts serializados e validados com Zod antes de salvar/restaurar.
- [ ] **Responsive breakpoints** — layouts definidos para lg, md, sm, xs. Testado em mobile.
- [ ] **Drag handle explícito** — `draggableHandle=".widget-drag-handle"`, não superfície inteira.
- [ ] **Canvas rendering** — gráficos com > 500 pontos usam Canvas/WebGL, nunca SVG.
- [ ] **Batch data fetching** — UMA request para N widgets, não N requests paralelas.
- [ ] **Debounce em filtros** — ≥ 300ms de debounce antes de disparar re-query.
- [ ] **WebSocket para real-time** — throttled a 1 update/s máximo. NUNCA polling.
- [ ] **Sparklines SVG** — inline com SVG puro, sem importar library pesada.
- [ ] **Design mode vs View mode** — modos claramente separados com indicação visual.
- [ ] **Hierarquia visual** — KPIs no topo, chart principal no meio, tabela na base.
- [ ] **Dark mode tokens** — palette dedicada para dashboard com contrast ratio ≥ 4.5:1.
- [ ] **Keyboard navigation** — Arrow keys entre widgets, Enter para detalhe.
- [ ] **Screen reader** — `figcaption` em todo chart + tabela alternativa em `<details>`.
- [ ] **Performance budget** — LCP < 2.5s, INP < 200ms, bundle por widget < 50KB gzip.
- [ ] **Tabular-nums** — todos os números com `font-variant-numeric: tabular-nums`.
- [ ] **Date presets** — DateRangePicker com Hoje, 7d, 30d, 90d, YTD, Custom.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

