---
name: Token Efficiency & Zero-Token Code Reading
description: Enforce zero-token file reading patterns, surgical view_file usage, retry discipline, and build-only-on-stage-completion rules to minimize context window consumption across all Antigravity agents.
---

# Token Efficiency — Dogmas Invioláveis

## Princípio Central

**Cada token consumido sem necessidade é trabalho desperdiçado.** Esta skill governa como todos os agentes Antigravity lêem código, executam retries e disparam builds. Seguir estas regras é obrigatório — não opcional.

---

## DOGMA 1 — `view_file` Cirúrgico (Lei Zero-Token)

**NUNCA** leia um arquivo inteiro para encontrar uma linha específica.

```
# ERRADO — consome 20KB de contexto para encontrar 1 linha
view_file("frontend/src/components/KanbanBoard.tsx")  → 439 linhas

# CERTO — consome 6 linhas
grep_search("completed_at", "frontend/src/") → resultado: L95
view_file("KanbanBoard.tsx", StartLine=92, EndLine=100)
```

**Regra:** `view_file` sem `StartLine`/`EndLine` apenas em arquivos **< 80 linhas**.  
Para qualquer arquivo maior: **grep first, then range view**.

---

## DOGMA 2 — Hierarquia de Ferramentas (Menor → Maior Consumo)

Sempre usar a ferramenta com menor custo de tokens que resolve o problema:

| Prioridade | Ferramenta | Quando usar |
|---|---|---|
| 1 | `fs_semantic_search` | Busca por padrão em todo o codebase |
| 2 | `grep_search(MatchPerLine=true)` | Encontrar linha exata por literal/regex |
| 3 | `fs_read_minified` | Ler estrutura de arquivo (-40% tokens) |
| 4 | `view_file(StartLine, EndLine)` | Ler trecho específico já localizado |
| 5 | `view_file` sem range | **APENAS** arquivos < 80 linhas |

**Proibido:** pular direto para `view_file` sem range em arquivos grandes.

---

## DOGMA 3 — Pipeline Obrigatório para Editar Arquivos

```
1. fs_semantic_search / grep_search  →  encontra a linha/trecho exato
2. view_file(N-3, N+3)              →  confirma contexto mínimo
3. replace_file_content / multi_replace_file_content  →  edita só o trecho
```

**NUNCA** ler o arquivo inteiro "para entender o contexto" se já há informação suficiente.  
**NUNCA** usar `write_to_file(Overwrite=true)` para substituir um arquivo grande — isso re-escreve tudo.

---

## DOGMA 4 — Build/Test APENAS ao Concluir uma Etapa Completa

```
# ERRADO — build para testar 1 fix isolado
fix linha 101 → npm run build → testa → ajusta → npm run build → testa

# CERTO — agrupa todos os fixes da etapa, depois valida 1x
fix #1 → fix #2 → fix #3 → [ETAPA CONCLUÍDA] → npm run build → testa
```

**Regra:** `npm run build`, `cargo build`, `tsc`, `cargo check` apenas quando:  
(a) Uma etapa completa do Maestro for marcada como concluída, **OU**  
(b) O usuário solicitar explicitamente.

**Durante desenvolvimento incremental**: usar apenas `tsc --noEmit` para type-check se necessário.

---

## DOGMA 5 — Retry Máximo 2x (Lei Anti-Loop)

```
# ERRADO — 6 tentativas cegas de restart
restart → falhou → restart → falhou → restart → falhou → ...

# CERTO — diagnóstico antes da 3ª tentativa
restart → falhou
restart → falhou
PARAR → ps aux | grep <processo>
PARAR → lsof -ti:PORT
Identificar causa raiz → resolver → 1 tentativa definitiva
```

**Regra:** Após **2 falhas consecutivas** no mesmo comando:  
1. PARAR imediatamente  
2. Executar diagnóstico (`ps aux`, `lsof`, `systemctl status`, `journalctl -u`)  
3. Identificar a causa raiz  
4. Resolver a causa → executar 1x definitivo  

**NUNCA** variar o mesmo comando com flags diferentes sem diagnóstico.

---

## DOGMA 6 — Grep de Qualidade (Sem Regex Inválida)

```
# ERRADO — regex inválida consome tokens sem retorno
grep_search(Query="new Date\|toLocaleDateString\|format(", IsRegex=true)

# CERTO — queries separadas e literais
grep_search(Query="new Date(", IsRegex=false)
grep_search(Query="toLocaleDateString", IsRegex=false)
```

**Regra:** Usar `IsRegex=false` para buscas literais. Dividir queries complexas em chamadas simples.  
Usar `IsRegex=true` **apenas** quando a regex está testada e correta.

---

## DOGMA 7 — Externalizar Contexto Complexo

Para tarefas que span múltiplos arquivos ou sessões:

1. **Persistir** decisões em `AI.md`, `ROADMAP.md` ou artefatos do brain.
2. **Micro-commits** após cada fix funcional — não acumular 10 mudanças.
3. **Hive Mind** (`aiops_create_knowledge`) para erros resolvidos e padrões descobertos.

**NUNCA** acumular contexto na janela de conversa quando pode ser externalizado.

---

## Checklist — Antes de Qualquer Ação de Leitura de Código

- [ ] O arquivo tem < 80 linhas? → `view_file` sem range OK
- [ ] Sei a linha aproximada via grep? → `view_file(N-5, N+5)`
- [ ] Preciso da estrutura geral? → `fs_read_minified` primeiro
- [ ] Já li este arquivo nesta sessão? → reusar o contexto existente, não reler

## Checklist — Antes de Qualquer Build

- [ ] A etapa do Maestro está concluída? → build OK
- [ ] O usuário pediu explicitamente? → build OK
- [ ] É um fix isolado mid-stage? → **NÃO BUILDAR**, agrupar com próximos fixes
