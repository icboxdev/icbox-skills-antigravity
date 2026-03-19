---
name: Git Deploy Mastery
description: Detect, validate, merge, and push Git repositories for production deploy. Auto-discovers repo structure (mono, nested, submodules), detects build tools (Rust, Node, Python, Go), enforces pre-deploy checklist, and pushes all branches to remotes. Stack-agnostic.
---

# Git Deploy Mastery — Deploy Autônomo Stack-Agnostic

## 1. Princípio Zero

Deploy é uma operação **destrutiva e irreversível em produção**. O agente DEVE seguir este fluxo **exatamente**, sem pular etapas, independente da stack ou estrutura do projeto.

## 2. Fase 1 — Discovery (Auto-Detecção)

Antes de qualquer merge, o agente DEVE detectar:

### 2.1 Estrutura de Repositórios
```bash
# Encontrar todos os repos git no workspace
find <WORKSPACE_ROOT> -name ".git" -type d -maxdepth 4 | sort
```

Classificar como:
- **Single Repo**: apenas `.git` na raiz
- **Nested Repos**: múltiplos `.git` em subdiretórios (repos independentes aninhados)
- **Git Submodules**: presença de `.gitmodules` na raiz

### 2.2 Detecção de Build Tools
Para cada repo encontrado, detectar a stack:

| Arquivo | Stack | Comando de Check |
|---|---|---|
| `Cargo.toml` | Rust | `cargo check` |
| `package.json` (com `build` script) | Node.js | `npm run build` |
| `go.mod` | Go | `go build ./...` |
| `pyproject.toml` / `setup.py` | Python | `python -m py_compile` |
| `Makefile` | Make | `make check` ou `make build` |

### 2.3 Detecção de Branches
```bash
# Para cada repo
git branch --list dev develop main master
```
Identificar: branch de trabalho (`dev`/`develop`) e branch de produção (`main`/`master`).

## 3. Fase 2 — Pre-Deploy Checklist (OBRIGATÓRIO)

**NUNCA mergear se qualquer item falhar.**

### 3.1 Build Check
Para CADA repo que tem build tool detectado, executar o build check correspondente. TODOS devem passar com exit code 0.

### 3.2 Uncommitted Changes
```bash
# Para CADA repo
git status --short
```
Se houver arquivos dirty → commitar ANTES do merge. Perguntar ao usuário se não for óbvio o que commitar.

### 3.3 Branch Divergence
```bash
# Verificar se dev está à frente de main
git log main..dev --oneline
```
Se dev NÃO está à frente → informar "Nada para deployar neste repo".

## 4. Fase 3 — Deploy (Merge + Push)

### 4.1 Ordem de execução para Nested Repos
1. **Repos internos PRIMEIRO** (em qualquer ordem entre si)
2. **Repo parent POR ÚLTIMO** (se existir e tiver remote)

### 4.2 Comando para CADA repo
```bash
cd <REPO_PATH>
git checkout main          # ou master
git merge dev --no-ff -m "chore: merge dev into main for deploy"
git push origin main       # Push main para remote
git push origin dev        # Push dev também (manter remote atualizado)
git checkout dev           # Voltar para branch de trabalho
```

### 4.3 Repos sem remote
Se `git remote -v` retorna vazio → apenas merge local, sem push. NÃO dar erro.

## 5. Dogmas Invioláveis

- **NUNCA** pular o build check. Se `cargo check` falha, PARAR.
- **NUNCA** fazer push sem ter feito merge local primeiro.
- **NUNCA** deixar um repo sem push quando ele TEM remote configurado.
- **NUNCA** assumir que existe apenas 1 repo — SEMPRE detectar a estrutura.
- **NUNCA** fazer merge para main sem solicitação EXPLÍCITA do usuário.
- **SEMPRE** voltar para a branch de trabalho (dev) após o merge.
- **SEMPRE** reportar o resultado final com tabela: repo | branch | commit | pushed.

## 6. Few-Shot: Fluxo Completo

```
# CERTO — Deploy completo
1. find . -name ".git" → detectou 4 repos
2. cargo check → ✅ | npm run build → ✅
3. git status em cada → 1 dirty → commit
4. Para cada repo: checkout main → merge dev → push main → push dev → checkout dev
5. Tabela final com status de cada repo

# ERRADO — O que causou falha anteriormente
1. Merge apenas no parent
2. Não push nos repos internos
3. Não detectou que gateway tinha changes pendentes
4. Push falhou no parent (sem remote) e parou sem tentar os outros
```

## 7. Tabela de Resultado Final (Template)

Após deploy, SEMPRE apresentar:

```markdown
| Repo | dev | main | Pushed | Remote |
|---|---|---|---|---|
| analytic/api | `abc123` | `def456` | ✅ | github.com/org/repo |
| analytic/app | `ghi789` | `jkl012` | ✅ | github.com/org/repo |
| storage | `mno345` | `pqr678` | ❌ sem remote | — |
```
