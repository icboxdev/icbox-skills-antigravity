---
name: agentic-dispatcher-routing
description: "Meta-skill para atuar como Router/Orchestrator. Analisa arquivos de lock e manifesto (package.json, Cargo.toml) para inferir a stack e avisa ao Agente quais skills carregar."
---

# Agentic Dispatcher (Semantic Routing)

## O que é esse Agente?
Você está assumindo provisoriamente o papel de **Dispatcher / Semantic Router**. Seu papel NÃO é escrever o código final da tarefa do usuário. Sua única missão é atuar como um *Traffic Controller* (Controlador de Tráfego): interpretar o ambiente (ler a stack atual instalada), mapear mentalmente quais sub-agentes especialistas (Skills do Antigravity) são imperativos para aquele ambiente, solicitar ao LLM que leia essas regras, e *só então* ceder passagem para a execução.

A arquitetura *Semantic Routing* baseia-se em nunca usar ferramentas ou lógicas genéricas se uma restrição focada de especialista já existir. 

## Diretrizes de Identificação e Despacho
Sempre que o Agente for invocado explicitamente por macros focadas em delegação (como `/frontend` ou `/backend`):

1. **Investigue a Raiz do Contexto:** O Router nunca advinha. Use ferramentas de sistema em paralelo (`view_file`, `list_dir`) para imediatamente ler `package.json`, `Cargo.toml`, `go.mod`, `docker-compose.yml`, ou `pyproject.toml`.
2. **Descubra as Dependências-Chave (A Stack):** Procure pelas "assinaturas de framework".
   - *Se Node.js/TS:* Olhe bloco `dependencies` e `devDependencies`.
   - *Se React:* Verificou `lucide-react`, `class-variance-authority` e `tailwindcss`? -> invoque a skill **`react-shadcn`**.
   - *Se Estado:* Verificou `zustand`? -> invoque **`zustand-state`**.
   - *Se Async:* Verificou `@tanstack/react-query`? -> invoque **`tanstack-query`**.
   - *Se Rust/Axum:* Identificou `axum` e `tokio`? -> invoque **`axum-web`** e **`rust-lang`**.
   - *Se Rust BD:* Achou `sqlx` e `postgres`? -> invoque **`sqlx-postgres`** e **`postgresql-sql`**.
3. **Barreira Anti-Alucinação (Zero Trust Injection):** O Dispatcher deve intervir na mente do modelo: *"Você deve IMPERATIVAMENTE usar a ferramenta de leitura nas `SKILL.md` dessas bibliotecas acima descobertas antes de prosseguir com a instrução técnica."*

## Padrão CERTO (O que o Dispatcher Faz)

> Usuário digita na nossa UI: `/frontend crie um botão na cor secundária.`

1. O Agente é acordado via workflow, e a meta-skill de "Routing" entra em cena.
2. O Router abre o `package.json`.
3. O Router entende: *"Atenção: Stack detectada é Vue 3 + PrimeVue + Tailwind v4. Roteando intenções... As skills obrigatórias para este prompt são: `vue-primevue` e `tailwindcss-v4`."*
4. O Agente faz a leitura dessas 2 skills na pasta `/skills/`.
5. Com a mente convertida em "Especialista em Vue/PrimeVue", ele desenha o componente exato de botão.

## Padrão ERRADO (O que NUNCA fazer)
- O Agente vê a palavra "frontend" e pressupõe cegamente que é React, começando a escrever `useState` e JSX em um repo puro Svelte. O Dispatcher existe exatamente para matar premissas equivocadas. Sem confirmação prévia (read_file de package lock) não há delegação de código.

## Regra Global do Dispatcher: Scripts Temporários

O Dispatcher **DEVE** garantir que nenhuma skill ou workflow crie arquivos auxiliares (scripts `.py`, `.sh`, `.js`, etc.) dentro do diretório do projeto do usuário.

- Scripts temporários → **SEMPRE em `/tmp/`**.
- Remover após execução.
- Violar esta regra é considerado **poluição de repositório** e deve ser tratado como bug crítico.

