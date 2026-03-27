---
name: Advanced Error Investigation
description: Investigate, isolate, and perform Root Cause Analysis (RCA) on complex software errors. Enforces systematic step-by-step stack trace reading, performance bottleneck isolation, and deterministic debugging without blind guessing.
---

# Advanced Error Investigation — Diretrizes de Root Cause Analysis (RCA)

## 1. Princípio Zero: Pare de Tentar Adivinhar

A tentativa e erro sem método é a inimiga da produtividade sênior. Ao encontrar um erro cabeludo ou gargalo de performance, PARE. Não gere um `console.log` novo sem antes ler TODA a pilha atual de eventos. O problema verdadeiro raramente está na linha onde o aplicativo quebrou, mas no evento assíncrono que gerou o estado incorreto.

## 2. Leitura Cirúrgica de Stack Trace

O Agente DEVE analisar o stack trace inteiro, de cima (ponto de falha) até embaixo (origem no user land):
- **Identifique o Limite do Framework:** Ignore erros genéricos ocorrendo internamente nas bibliotecas (`node_modules/react-dom`, `node_modules/axum`) e busque pela **primeira linha do stack** que aponte para código escrito na aplicação (`src/*`).

```text
// CERTO - O RCA para aqui:
at processUser (/app/src/services/user.ts:42) // A ORIGEM DA FALHA ESTÁ AQUI.

// ERRADO - Culpar o framework:
at execute (/app/node_modules/postgres/index.js:123)
```

## 3. Isolamento e "Divide to Conquer"

Quando um erro complexo surgir:
1. Comente dependências laterais para aisolar o módulo suspeito.
2. Se o erro for de renderização no React/Next.js, desabilite Server-Side Rendering (SSR) temporariamente para verificar se é um problema de "Hydration Mismatch".
3. Valide o payload real no network vs o tipo inferido: A maioria dos erros inexplicáveis vem de uma API enviando um número onde se esperava string. Valide o input via console.

## 4. Identificando Gargalos de Performance

Se o usuário reportar lentidão extrema:
- **No Frontend:** Suspeite imediatamente de N+1 Renders. Liste hooks dependentes de propriedades não memoizadas (ausência de `useMemo` ou `useCallback` causando renderização infinita) ou useEffects trigando updates em cascata.
- **No Backend:** Suspeite de queries Database N+1 (consultas num loop). Busque ocorrências de queries não parametrizadas limitando tamanho excessivo no banco.

## 5. Workflow Determinístico

1. Reproduzir o bug mentalmente com a evidência técnica (logs/terminal).
2. Isolar a origem no código, verificando o stack trace (RCA).
3. Testar a suposição com comandos diretos (`grep`, inspeção visual de tipos) ou solicitar ao usuário inspeção de DevTools/Network Tab.
4. Aplicar correção focada única no arquivo raiz do problema. Nunca refatore lógica vizinha antes que o erro central esteja consertado.

## 6. Debugging Microservices — Error Masking Trap

Em arquiteturas de microserviços, erros frequentemente cruzam fronteiras entre serviços. O **error masking** é o maior inimigo:

```
Service A → Service B → Service C
                        ↑ ERRO REAL: "column scope is of type ApiKeyScope"
                ↑ MASCARADO: "Internal server error"
        ↑ MASCARADO²: "Failed to create key: 500 — Internal server error"
```

**Workflow para M2M Debugging:**
1. **Identifique a cadeia:** trace o request path entre serviços (A→B→C).
2. **Leia os LOGS do serviço FINAL** (onde o 500 origina), não do intermediário.
3. Se os logs são insuficientes: **melhore o error handler** para expor detalhes na resposta (temporária ou permanentemente em M2M).
4. **Nunca assuma que o deploy aterrissou** — confirme a versão em produção antes de debugar código.

**Regra:** Ao investigar 500 entre serviços, o PRIMEIRO passo é garantir que o erro real está visível. Se não está, fix o error handler ANTES de tentar fixar o bug.

## 7. Gotcha: Schema Changes Outside Migrations

Quando o banco de dados é alterado diretamente (DDL fora das migrations), o código pode quebrar de formas não-óbvias:

- **Enum types:** `ALTER COLUMN ... TYPE enum` → INSERTs com text falham
- **DEFAULTs perdidos:** `ALTER TABLE` pode dropar DEFAULTs de colunas adjacentes
- **Checksum mismatch:** `sqlx::migrate!()` detecta alteração e recusa rodar

**Regra:** Sempre investigate se o schema DB está igual ao que as migrations definem. Use `\d+ tablename` no psql para comparar com o `001_init.sql`.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

