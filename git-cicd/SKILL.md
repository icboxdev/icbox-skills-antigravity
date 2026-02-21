---
name: Git & CI/CD Workflows
description: Validate, enforce, and generate Git branching strategies, conventional commits, GitHub Actions pipelines, and PR review conventions. Covers trunk-based development, semantic versioning, and deployment automation.
---

# Git & CI/CD — Diretrizes Sênior

## 1. Zero-Trust & Limites de Contexto

- **Antes de configurar CI/CD**, externalize a estratégia de deploy em artefato.
- Faça **micro-commits**: um job/step por vez no workflow.
- **Secrets SEMPRE no GitHub Secrets Manager**. Nunca em código ou comentário.
- Validar workflows localmente com `act` antes de push.

## 2. Branching — Trunk-Based Development

```
main ─────────────────────────────────────────→ (produção)
  ├── feat/add-user-profile ──→ PR → merge
  ├── fix/login-redirect ──→ PR → merge
  └── chore/upgrade-deps ──→ PR → merge
```

- `main` = produção. Sempre deployável.
- Feature branches: `feat/`, `fix/`, `chore/`, `refactor/`, `docs/`.
- Branches curtas (< 3 dias). Long-lived branches = merge conflicts.
- Nunca commit direto em `main`.

## 3. Conventional Commits

```bash
# ✅ CERTO — commit semântico, escopo, descrição clara
git commit -m "feat(auth): add PKCE flow for SSR authentication"
git commit -m "fix(pipeline): prevent stage move without required fields"
git commit -m "chore(deps): upgrade prisma to v6.19"
git commit -m "refactor(leads): extract scoring to dedicated service"

# ❌ ERRADO — commits genéricos
git commit -m "fix stuff"
git commit -m "update"
git commit -m "wip"
```

### Prefixos

| Prefixo           | Quando                      | Semver |
| ----------------- | --------------------------- | ------ |
| `feat`            | Nova feature                | minor  |
| `fix`             | Bug fix                     | patch  |
| `chore`           | Deps, config, CI            | —      |
| `refactor`        | Reestruturação sem feat/fix | —      |
| `docs`            | Documentação                | —      |
| `test`            | Testes                      | —      |
| `perf`            | Performance                 | patch  |
| `BREAKING CHANGE` | No footer do commit         | major  |

## 4. GitHub Actions — Padrões

### 4.1 CI Workflow

```yaml
# ✅ CERTO — CI completo com cache, lint, test, build
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: "npm"

      - run: npm ci

      - name: Lint
        run: npm run lint

      - name: Type Check
        run: npx tsc --noEmit

      - name: Test
        run: npm run test -- --coverage

      - name: Build
        run: npm run build
```

### 4.2 Deploy com Coolify Webhook

```yaml
# ✅ CERTO — deploy automático via Coolify API
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    if: github.event_name == 'push'
    steps:
      - name: Trigger Coolify Deploy
        run: |
          curl -X POST "${{ secrets.COOLIFY_URL }}/api/v1/applications/${{ secrets.APP_UUID }}/deploy" \
            -H "Authorization: Bearer ${{ secrets.COOLIFY_TOKEN }}" \
            -H "Content-Type: application/json"

# ❌ ERRADO — secrets no workflow
# env:
#   COOLIFY_TOKEN: "ck_1234567890"  # EXPOSTO no log!
```

## 5. Pull Requests — Convenções

### Template de PR

```markdown
## O que faz?

Breve descrição da mudança.

## Tipo

- [ ] feat
- [ ] fix
- [ ] refactor
- [ ] chore

## Checklist

- [ ] Testes adicionados/atualizados
- [ ] Lint passa sem erros
- [ ] Build está funcional
- [ ] Docs atualizados (se aplicável)
```

### Regras

- Título segue conventional commits: `feat(auth): add OAuth2 login`.
- Squash merge para manter histórico limpo.
- Mínimo 1 approval antes de merge.
- Branch auto-delete após merge.

## 6. Anti-Patterns

- ❌ `git push --force` em `main` — NUNCA (apenas em branch pessoal: `--force-with-lease`)
- ❌ Commits com `node_modules`, `.env`, `dist/` — `.gitignore` obrigatório
- ❌ Merge commits (poluem histórico) — usar squash merge
- ❌ Branch > 1 semana — dividir em PRs menores
- ❌ CI sem cache — adicionar `actions/cache` ou `setup-node` com cache
