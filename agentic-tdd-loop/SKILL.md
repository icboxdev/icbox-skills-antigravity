---
name: Agentic TDD & Self-Healing Loop
description: Architect, establish, and enforce autonomous Test-Driven Development loops for LLM Agents. Dictates strict rules for test-first development, fail-fast compilation, and bounded self-healing iterations without human intervention.
---

# Agentic TDD & Self-Healing Loop

O maior ganho de assertividade de um Engenheiro de IA ocorre quando ele **avalia o próprio trabalho antes de entregá-lo**. A skill de *Agentic TDD (Test-Driven Development)* e *Self-Healing (Auto-cura)* converte tentativas cegas em loops operacionais com provas de compilação lógicas. Você passa a atuar não como um "Escritor de Código", mas como um "Testador Autônomo".

## Arquitetura & Dogmas OBRIGATÓRIOS

- **Test-First (TDD Estrito)**: Antes de codificar uma lógica complexa em um arquivo alvo (ex: `math.rs` ou `auth.ts`), crie o arquivo de teste `math.test.ts` e escreva o cenário de falha. É PROIBIDO adivinhar o comportamento de lógicas isoladas sem escrever o cenário que prova o defeito.
- **Fail-Fast Output (Controle de Tokens)**: Rodar suites de teste gera logs massivos que estouram a *context window*.
  - No Node (Vitest): NUNCA rode `vitest run`, rode estritamente `vitest run --reporter=json` ou `--reporter=verbose` filtrando o arquivo exato. E utilize a ferramenta Mínima (`mcp_antigravity-core_test_executor_summary` ou grep).
  - No Rust (Cargo Test): NUNCA rode `cargo test` global. Rode `cargo test <nome_da_unidade> -- --nocapture` ou `cargo test --quiet`.
- **Limitação de Loop (Self-Healing Bounds)**: O Agente pode iterar sobre mensagens de erro. Porém, NUNCA itere infinitamente na mesma refatoração. O limite máximo absoluto de tentativas sucessivas de "Consertar, Rodar Teste, Falhar" é **5 (cinco) vezes**. Se a quinta vez falhar, DEVOLVA imediatamente a autoridade para o usuário humano solicitando insights.
- **Unidade antes de E2E**: Testes focados no *Self-Healing* devem demorar milissegundos. Restrinja o TDD Autônomo para regras de Unit Tests e Integration Tests (Vitest, Cargo Test). NUNCA faça Loops TDD em testes End-to-End (Playwright) durante exploração, por conta do delay algorítmico do navegador *headless*.

## Few-Shot: Fluxo TDD de Autocura

### 🟢 CORRETO
O Agente recebe uma tarefa para criar um cálculo financeiro.
1. O agente usa `write_to_file` criando `finances.test.ts` e codifica que `calculate_tax(100)` deve retornar `15`.
2. O agente chama `run_command` executando `npx vitest run finances.test.ts`. O console retorna `ReferenceError: calculate_tax is not defined`.
3. O agente lê a falha, entende a semântica, cria `finances.ts` exportando a função com lógica errada (ex: `return amount * 0.10`).
4. O agente roda o teste. O console diz: `Expected 15, received 10`.
5. O agente refatora o arquivo com `return amount * 0.15`.
6. O teste responde `Verde (Pass)`. O agente encerra a tarefa e avisa o usuário.

### 🔴 ERRADO
O Agente escreve toda a lógica complexa que o usuário pediu num mega-arquivo `services/finances.ts`, diz "Está pronto!" pro usuário e **espera** que o usuário vá rodar os testes na mão e sirva como debugador ("deu erro na linha 44"). Isso não é Inteligência Autônoma, é digitação rápida.

## Context Management & Zero-Trust

- **Evite Cores e ANSI**: IAs não leem cor. Se você rodar comântos de terminal, sempre exija desativação de cores para otimizar a extração textutal (ex: `NO_COLOR=1 npm test`).
- O auto-healing só surte efeito com limites e provas concretas. Cada alteração que visa arrumar a falha DEVE possuir embasamento (*por que falhou? O que a stack trace nos diz?*), não mude código as cegas como *trial-and-error* na loucura.
- Nunca esconda a sujeira: Se estourou as 5 tentativas de autocura, diga expressamente via `walkthrough` ("Tentei X, Y e Z abordagens. Os testes ainda alegam o erro W. Por favor, reveja se as asserções estão de acordo.").
