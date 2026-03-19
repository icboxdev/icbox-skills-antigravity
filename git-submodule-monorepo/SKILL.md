---
name: Git Submodule & Monorepo Patterns
description: Validate, orchestrate, and manage Git submodule workflows, subtree splitting, detached HEAD prevention, CI automation, and multi-repo development patterns for polyglot projects.
---

# Git Submodule & Monorepo — Workflows, Subtree & CI

## 1. Propósito

Dominar workflows de Git submodules e subtrees para projetos multi-repo. Evitar os erros comuns (detached HEAD, commits perdidos, submodule desatualizado) e automatizar CI para repos compostos.

## 2. Dogmas Arquiteturais

### Submodule ≠ Diretório Normal

**NUNCA** tratar um submodule como diretório normal. Commits devem ser feitos DENTRO do submodule primeiro, depois o ponteiro atualizado no parent.

### Sempre Branch Named

**NUNCA** trabalhar em detached HEAD dentro de um submodule. **SEMPRE** fazer checkout de um branch antes de commitar.

### Parent Commit Após Submodule

Após commitar no submodule, **SEMPRE** commitar o ponteiro atualizado no parent repo.

## 3. Patterns Essenciais

### 3.1 Workflow de Submodule

```bash
# CERTO — Workflow completo de edição em submodule
# 1. Entrar no submodule
cd analytic/app

# 2. Garantir que está em branch named (NÃO detached HEAD)
git checkout dev

# 3. Fazer alterações, commitar e push
git add -A
git commit -m "feat: add dashboard component"
git push origin dev

# 4. Voltar ao parent e commitar o ponteiro
cd ../..
git add analytic/app
git commit -m "chore: update analytic/app submodule"
git push
```

```bash
# ERRADO — Commitar em detached HEAD
cd analytic/app
# HEAD detached at abc1234  ← PERIGO
git add -A
git commit -m "changes"  # Commit fica orfão, será garbage collected!
```

### 3.2 Clone com Submodules

```bash
# CERTO — Clone recursivo
git clone --recurse-submodules https://github.com/org/project.git

# Ou, após clone normal:
git submodule init
git submodule update
```

```bash
# ERRADO — Clone sem submodules
git clone https://github.com/org/project.git
cd project/analytic/app  # Diretório vazio!
```

### 3.3 Atualizar Submodules

```bash
# CERTO — Atualizar para último commit do branch tracked
git submodule update --remote --merge

# Atualizar submodule específico
git submodule update --remote analytic/app
```

### 3.4 Subtree Split para Deploy

```bash
# CERTO — Extrair subdiretório para deploy independente
# Quando o submodule tem seu próprio repo de deploy

# Push do subdiretório para repo separado
git subtree push --prefix=analytic/app origin-app main

# Ou split + push manual
git subtree split --prefix=analytic/app -b deploy-branch
git push origin-app deploy-branch:main
```

### 3.5 CI com Submodules

```yaml
# CERTO — GitHub Actions com submodules
name: Build
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive    # ← Essencial
          fetch-depth: 0

      - name: Build submodule
        working-directory: analytic/app
        run: |
          npm ci
          npm run build
```

```yaml
# ERRADO — Checkout sem submodules
- uses: actions/checkout@v4
# submodules: false (default) → diretórios vazios
```

### 3.6 .gitmodules

```ini
# .gitmodules
[submodule "analytic/app"]
    path = analytic/app
    url = https://github.com/org/analytic-app.git
    branch = dev

[submodule "analytic/api"]
    path = analytic/api
    url = https://github.com/org/analytic-api.git
    branch = dev
```

## 4. Comandos Git para Submodules

| Comando | O que faz |
|---------|-----------|
| `git submodule status` | Mostra commit atual de cada submodule |
| `git submodule foreach 'git status'` | Roda comando em todos os submodules |
| `git submodule update --init` | Inicializa e atualiza |
| `git submodule update --remote` | Atualiza para último commit do remote |
| `git diff --submodule` | Mostra diff incluindo submodules |
| `GIT_EDITOR=true git merge dev --no-edit` | Merge sem abrir editor (scripts) |

## 5. Troubleshooting

| Problema | Causa | Solução |
|----------|-------|---------|
| "fatal: Pathspec in submodule" | `git add` executado no parent para path de submodule | Executar `git add` DENTRO do submodule |
| Detached HEAD após update | `git submodule update` checkout commit específico | `git checkout dev` dentro do submodule |
| Submodule shows "dirty" | Mudanças não commitadas dentro | Commitar ou descartar dentro do submodule |
| Merge conflict em submodule pointer | Parent refs divergiram | Escolher um commit, `git add submodule-path` |

## 6. Zero-Trust

- **NUNCA** fazer `git add .` no parent incluindo submodules sem verificar.
- **NUNCA** commitar em detached HEAD dentro de submodule.
- **NUNCA** assumir que submodules estão atualizados após `git pull` — rodar `git submodule update`.
- **SEMPRE** verificar `git submodule status` antes de deployar.
- **SEMPRE** usar `--recurse-submodules` no clone para CI/CD.
- **SEMPRE** usar `GIT_EDITOR=true` ou `--no-edit` em scripts para evitar nano/vim travando.
