---
name: SVG Icon & Logo Design
description: Generate, validate, and optimize SVG icons, logos, and illustrations. Enforces proper path commands, viewBox coordinate systems, fill-based solid shapes, gradient definitions, accessibility, and SVGO optimization patterns.
---

# SVG Icon & Logo Design — Skill

## 1. Princípio: SVGs como Código

SVGs são XML vetorial — trate como código, não como imagem. Todo SVG gerado deve ser:

- **Semântico** — usar `<path>`, `<rect>`, `<circle>` ao invés de polígonos arbitrários quando possível.
- **Otimizado** — mínimo de pontos, sem decimais desnecessárias, sem metadata de editor.
- **Acessível** — `role="img"` e `aria-label` quando usado inline.

## 2. Dogmas Arquiteturais

### viewBox

- **SEMPRE** defina `viewBox` em todo SVG. NUNCA use `width`/`height` fixos sem viewBox.
- Use coordenadas inteiras e simples: `viewBox="0 0 24 24"` (ícones), `viewBox="0 0 48 48"` (logos).
- O viewBox define o sistema de coordenadas INTERNO. Width/height controlam o tamanho de exibição.

### Shapes First, Paths Second

- Para formas simples, **SEMPRE use elementos nativos** (`<rect>`, `<circle>`, `<ellipse>`, `<line>`, `<polygon>`).
- Use `<path>` APENAS quando a forma é complexa demais para elementos nativos.

### Fill vs Stroke

- Para **ícones sólidos / logos**: use `fill` (preenchimento). Produz shapes limpas e escaláveis.
- Para **ícones de linha (outline)**: use `stroke` com `stroke-width`, `stroke-linecap="round"`, `stroke-linejoin="round"`.
- **NUNCA** misture fill e stroke no mesmo path sem intenção clara.

### currentColor

- Para ícones temáticos, use `fill="currentColor"` ou `stroke="currentColor"` para herdar a cor do CSS pai.
- Para logos com cor fixa, use cores hex ou gradientes definidos em `<defs>`.

## 3. Path Commands — Referência Rápida

O atributo `d` do `<path>` aceita estes comandos:

| Comando                       | Nome         | Parâmetros           | Descrição                    |
| ----------------------------- | ------------ | -------------------- | ---------------------------- |
| `M x y`                       | MoveTo       | ponto                | Move o cursor (sem desenhar) |
| `L x y`                       | LineTo       | ponto                | Desenha linha reta           |
| `H x`                         | Horizontal   | x                    | Linha horizontal             |
| `V y`                         | Vertical     | y                    | Linha vertical               |
| `Z`                           | ClosePath    | —                    | Fecha o path (volta ao M)    |
| `C x1 y1 x2 y2 x y`           | Cubic Bézier | 2 controles + ponto  | Curva suave complexa         |
| `S x2 y2 x y`                 | Smooth Cubic | 1 controle + ponto   | Continuação suave de C       |
| `Q x1 y1 x y`                 | Quadratic    | 1 controle + ponto   | Curva simples                |
| `T x y`                       | Smooth Quad  | ponto                | Continuação de Q             |
| `A rx ry rot large sweep x y` | Arc          | raio + flags + ponto | Arco elíptico                |

- **Maiúsculas** = coordenadas absolutas. **Minúsculas** = relativas.
- `Z` não tem diferença entre maiúscula/minúscula.

### Técnica: Construir Formas com Path

Para criar letras, ícones ou logos geométricos:

1. **Planeje no grid** — Defina o viewBox e trace os pontos-chave.
2. **Comece com M** — Mova para o primeiro ponto.
3. **Use L/H/V** — Para linhas retas (maioria dos logos geométricos).
4. **Use C/Q** — Para curvas (bordas arredondadas, logos orgânicos).
5. **Feche com Z** — Para formas fechadas.

## 4. Few-Shot: Ícone Sólido (24x24)

```svg
<!-- ✅ CERTO — Ícone check sólido com fill -->
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path
    d="M9 16.2L4.8 12l-1.4 1.4L9 19 21 7l-1.4-1.4L9 16.2z"
    fill="currentColor"
  />
</svg>

<!-- ❌ ERRADO — Sem viewBox, size fixo, stroke desnecessário -->
<svg width="24" height="24">
  <path d="M9 16.2L4.8 12l-1.4 1.4L9 19 21 7l-1.4-1.4L9 16.2z"
    stroke="black" stroke-width="1" fill="black" />
</svg>
```

## 5. Few-Shot: Logo Geométrico com Gradiente

```svg
<!-- ✅ CERTO — Logo com gradiente em defs, path único, viewBox limpo -->
<svg viewBox="0 0 48 40" fill="none" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="brand" x1="0" y1="0" x2="0" y2="40" gradientUnits="userSpaceOnUse">
      <stop offset="0%" stop-color="#0d9488" />
      <stop offset="100%" stop-color="#2dd4bf" />
    </linearGradient>
  </defs>
  <!-- M sólido — um único path unificado -->
  <path d="M0 40V0H10L24 20L38 0H48V40H38V16L24 36L10 16V40Z" fill="url(#brand)" />
</svg>

<!-- ❌ ERRADO — Múltiplos rects separados tentando formar uma letra -->
<svg viewBox="0 0 48 40">
  <rect x="0" y="0" width="8" height="40" fill="green"/>
  <rect x="40" y="0" width="8" height="40" fill="green"/>
  <rect x="15" y="10" width="5" height="15" fill="green" transform="rotate(-30)"/>
  <rect x="25" y="10" width="5" height="15" fill="green" transform="rotate(30)"/>
</svg>
```

## 6. Few-Shot: Construindo uma Letra M Passo a Passo

Para criar letras/formas geométricas, trace os pontos no grid do viewBox:

```
ViewBox: 0 0 48 40

Pontos do M (sentido horário, borda externa):
  (0,40) → (0,0) → (10,0) → (24,20) → (38,0) → (48,0) → (48,40) → (38,40) → (38,16) → (24,36) → (10,16) → (10,40)

Path: M0 40 V0 H10 L24 20 L38 0 H48 V40 H38 V16 L24 36 L10 16 V40 Z

Decomposição:
  M0 40    → start bottom-left
  V0       → sobe pilar esquerdo
  H10      → topo do pilar esquerdo (largura 10)
  L24 20   → diagonal descendo ao centro (vale do V)
  L38 0    → diagonal subindo ao pilar direito
  H48      → topo do pilar direito
  V40      → desce pilar direito (externo)
  H38      → base do pilar direito (interno)
  V16      → sobe pilar direito (interno) até onde começa o V
  L24 36   → diagonal interno descendo ao centro
  L10 16   → diagonal interno subindo ao pilar esquerdo
  V40      → desce pilar esquerdo (interno)
  Z        → fecha (volta ao M0 40)
```

## 7. Adicionando Detalhes (Setas, Badges, Acentos)

Para adicionar elementos decorativos (setas de crescimento, check marks, badges):

```svg
<!-- ✅ CERTO — Seta como path separado, mesma cor/gradiente -->
<svg viewBox="0 0 56 44" fill="none">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="0" y2="44" gradientUnits="userSpaceOnUse">
      <stop offset="0%" stop-color="#0d9488"/>
      <stop offset="100%" stop-color="#2dd4bf"/>
    </linearGradient>
  </defs>
  <!-- Corpo principal -->
  <path d="M0 44V0H10L24 22L38 0H48V34H39V16L24 38L10 16V44Z" fill="url(#g)"/>
  <!-- Seta: diagonal + arrowhead como paths fills -->
  <path d="M39 12L37 7L49 0H56V7H50V13H44L44 6L41 8Z" fill="url(#g)"/>
</svg>

<!-- ❌ ERRADO — Seta com strokes finos descombinando com body fill -->
<path d="M40 10L50 2" stroke="green" stroke-width="2"/>
<path d="M50 2L50 8" stroke="green" stroke-width="2"/>
```

## 8. Otimização

### Regras de Otimização

- **Arredonde coordenadas** para inteiros sempre que possível.
- **Elimine espaços redundantes**: `M0 40V0H10` ao invés de `M 0 40 V 0 H 10`.
- **Combine paths** quando possível — menos elementos = menor DOM.
- **Remova atributos default**: `fill-rule="nonzero"` é default, não precisa declarar.
- **Use H/V** ao invés de L quando a linha é horizontal/vertical.

### Checklist de Qualidade

1. ✅ `viewBox` definido com coordenadas inteiras
2. ✅ `fill="none"` no elemento `<svg>` (evita fill preto default)
3. ✅ Gradientes em `<defs>` com `id` único
4. ✅ Paths usando coordenadas inteiras (sem decimais)
5. ✅ Sem `width`/`height` hardcoded (tamanho controlado pelo parent)
6. ✅ Forma coerente — testar renderização antes de entregar

## 9. Acessibilidade

```tsx
// ✅ CERTO — SVG inline acessível
<svg viewBox="0 0 24 24" role="img" aria-label="Ícone de configurações">
  <path d="..." fill="currentColor" />
</svg>

// ✅ Para SVG decorativo (não informativo)
<svg viewBox="0 0 24 24" aria-hidden="true">
  <path d="..." />
</svg>
```

## 10. Integração com React/TSX

```tsx
// ✅ CERTO — Componente React com props tipadas
interface IconProps {
  size?: number;
  className?: string;
}

export function CheckIcon({ size = 24, className }: IconProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      className={className}
      aria-hidden="true"
    >
      <path
        d="M9 16.2L4.8 12l-1.4 1.4L9 19 21 7l-1.4-1.4L9 16.2z"
        fill="currentColor"
      />
    </svg>
  );
}
```

## Constraints — O que NUNCA Fazer

- ❌ NUNCA omita `viewBox` — sem ele o SVG não escala.
- ❌ NUNCA use coordenadas com mais de 1 casa decimal no path.
- ❌ NUNCA misture fill sólido no body com stroke fino nos detalhes (inconsistência visual).
- ❌ NUNCA crie formas com `<rect>` rotacionados quando um `<path>` é mais limpo.
- ❌ NUNCA use `transform="rotate()"` para construir letras — trace o path diretamente.
- ❌ NUNCA gere SVG sem testar a renderização visual.
- ❌ NUNCA hardcode width/height sem viewBox correspondente.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

