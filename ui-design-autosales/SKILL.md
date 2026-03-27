---
name: AutoSales UI/UX Engineering (Geist + React Aria)
description: Validate, generate, and govern the frontend UI/UX architecture for the AutoSales project. Enforces Vercel's Geist UI design system aesthetics, Adobe React Aria Components for WAI-ARIA compliance, and Tailwind CSS v4 styling within a Vite React application.
---

# AutoSales UI/UX Design System

Como Tech Lead e UX/UI Engineer para a plataforma AutoSales, você DEVE seguir estas diretrizes absolutas. O objetivo é combinar os hooks e componentes altamente acessíveis e headless do **Adobe React Aria Components** (RAC) com a estética profissional, limpa e "dark-first" do **Vercel/Geist Design System**.

## 1. Dogmas Estéticos (Geist Aesthetic)

A interface deve transparecer altíssima qualidade técnica e minimalismo focado na conversão e agilidade (vendedores não têm tempo para interfaces confusas).

- **Dark-First Minimalist:** O projeto é primariamente escuro. Use `#000` (`bg-black`) ou cinza extremamente escuro (`bg-zinc-950`) para o fundo principal da aplicação.
- **Hairline Borders:** Defina separações estruturais usando linhas de 1px (`border border-zinc-800` ou até `zinc-900`) e preserve os backgrounds limpos, evitando "card inside card" com cores fortes.
- **Micro-Tipografia (Geist Sans/Inter):** A fonte deve ser estritamente sem serifa, de alta legibilidade. Textos de ação (`text-zinc-100`), parágrafos e dados secundários (`text-zinc-400` / `text-zinc-500`).
- **Estados Visuais (Glows sutis):** Os botões principais e selects devem focar sutilmente quando interagidos (ex: `focus-visible:ring-2 focus-visible:ring-blue-600/50`). Não utilize gradientes agressivos.
- **Densidade Espacial Constante:** Componentes e cards no Kanban devem usar espaçamentos rigorosos, preferindo `gap-4` ou `gap-6` em wrappers gerais, e compactando dados (ex: `text-sm`, `py-1.5`) dentro dos cards de leads para aumentar a visualização da esteira.

## 2. Component Implementation (React Aria)

NUNCA crie elementos com interações complexas do zero (Dropdowns, Tabs, Selects Combinados, Drag-and-Drop, Popovers, Modais). SEMPRE utilize **React Aria Components (RAC)** como base.

- A estrutura do React Aria exporta tags semânticas e acessíveis (WAI-ARIA).
- A estilização ocorre injetando classes do Tailwind CSS nos render props ou capturando seletores nativos expostos (ex: `data-[hovered]`, `data-[focused]`, `data-[pressed]`, `data-[selected]`).
- Os formulários (`Form`) devem conectar suas reações validatórias diretamente ao Zod, gerenciados preferencialmente pelo React Hook Form em união com o Adobe RAC.

## 3. Padrões Específicos do AutoSales (Vendedor e Showroom)

O layout dos módulos deve seguir esta arquitetura:

- **O Painel Kanban (Modo Pipeline):**
  - Implementado com a semântica adequada. Cada coluna (`DropZone` / `div`) deve usar `bg-zinc-900/50` com leve borda. 
  - Os Cards de Leads devem ser limpos: Nome em cima (`font-medium`), WhatsApp, Status, e uma Tag de "Há X tempos sem contato" se necessário.
  - Ao arrastar (`onDragStart`), o card fica semi-transparente; o destino (coluna focada) ganha highlight com `bg-zinc-800/80` (Aesthetics do geist-ui/page).
- **Entradas Ágeis (Frictionless Forms):** 
  - Formulário "Novo Lead" ou "Appraisal (Avaliação)": Modal minúsculo, inputs amplos (`h-10` a `h-12`), fontes contrastantes, validação instantânea no KeyUp. Botão de submissão em full-width (`w-full`) para toque ágil com o polegar.
- **Showroom Gallery (Público):**
  - Diferente do admin, a área pública para os clientes busca "visceralidade". CSS Grid responsivo com foco nas imagens dos veículos (proporção 16:9 estrita com `object-cover`), cards finos sem muita sombra, favorecendo bordas translúcidas (`border-white/10`).

## 4. Anti-Patterns & Certo/Errado

### Estilização Estrita com React Aria
✅ **CERTO** (Construção Acessível + Tailwind condicional embutido nos estados do componente):
```tsx
import { Button } from 'react-aria-components';

<Button className="bg-zinc-100 text-zinc-950 px-4 py-2 font-medium rounded-md hover:bg-white data-[pressed]:bg-zinc-300 data-[focus-visible]:ring-2 ring-blue-500 outline-none transition-colors">
  Confirmar Proposta
</Button>
```

❌ **ERRADO** (Construir divs interativas com clicks genéricos, ignorando foco de teclado e acessibilidade do botão nativo Adobe):
```tsx
// ERRADO: Semanticamente falho, não funciona em screen-readers e ignora foco.
<div onClick={submitForm} className="bg-gray-800 text-white p-2 hover:bg-gray-700 cursor-pointer">
  Confirmar Proposta
</div>
```

### Renderização de Listas de Estoque e Leads (Vercel Style)
✅ **CERTO** (Utilização de linhas sutis com highlight hover para manter a interface clean e dados tabulares puros):
```tsx
<div className="flex flex-col border-y border-zinc-800">
  {leads.length === 0 ? (
    <div className="py-12 flex items-center justify-center text-sm text-zinc-500 bg-black">
      Nenhum cliente abandonado hoje.
    </div>
  ) : (
    leads.map(lead => (
      <LeadRow key={lead.id} data={lead} className="bg-black hover:bg-zinc-900/50 border-b border-zinc-800 last:border-0 transition-colors" />
    ))
  )}
</div>
```

❌ **ERRADO** (Uso exagerado de cartões coloridos super-estilizados com sombras desproporcionais prejudicando a performance visual):
```tsx
// ERRADO: Omitido o excesso de Drop Shadows, bordas redondas enormes (rounded-2xl) para uma tabela simples, ou gradientes desnecessários num contexto utilitário empresarial.
<div className="shadow-2xl rounded-3xl bg-gradient-to-r from-gray-900 to-black p-4">...</div>
```

## 5. State Management & Zero-Trust (Frontend Rules)

NUNCA ferir a reatividade básica com arquitetamentos lentos:

- **Server-State (Dados de Estoque e Leads):** DEVE obrigatoriamente usar `TanStack Query` (`useQuery`, `useMutation`). Se uma negociação é movida no Kanban, execute a mutação persistente e aplique a técnica de **Optimistic Update** do React Query (para resposta UI instantânea), desfazendo em caso de falha da API Adonis.
- **Client-State:** Use `Zustand` (MUITO esparso), apenas para estado global UI temporário (Ex: Toggle da Sidebar ou Filtros da tabela guardados até reload). 

## Regra Definitiva: UI = Utilitário
O seu Frontend deve parecer uma ferramenta de desenvolvedor ou software enterprise moderno (Ex: Vercel Dashboard, Supabase Dashboard, Stripe), combinando a escuridão minimalista (`zinc`, `black`) e precisão (React Aria). A prioridade é a velocidade (Frictionless) e não enfeites supérfluos.
