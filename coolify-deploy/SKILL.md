---
name: Coolify API & Deploy
description: Orchestrate and automate deployments via Coolify REST API. Covers authentication, application lifecycle, environment variables, webhooks, CI/CD patterns, and infrastructure provisioning.
---

# Coolify API & Deploy — Diretrizes Sênior

## 1. Zero-Trust & Limites de Contexto

- **Antes de criar scripts de deploy**, externalize a arquitetura de infra em um artefato.
- Faça **micro-commits**: configure um serviço por vez.
- Sempre rodar `--help` ou verificar documentação antes de executar CLIs do Coolify.
- Para referência completa de endpoints, consulte `resources/api-reference.md` desta skill.

## 2. Autenticação

```bash
# ✅ CERTO — token via env, nunca hardcode
curl -s https://coolify.seudominio.com/api/v1/teams \
  -H "Authorization: Bearer ${COOLIFY_API_TOKEN}" \
  -H "Content-Type: application/json"

# ❌ ERRADO — token hardcoded
curl -s https://coolify.seudominio.com/api/v1/teams \
  -H "Authorization: Bearer ck_1234567890abcdef"  # Exposto no histórico!
```

Gerar token: Settings → API Tokens → granular permissions.

## 3. Fluxo de Deploy Padrão

```
1. Criar/selecionar servidor     → GET /api/v1/servers
2. Criar/selecionar projeto      → POST /api/v1/projects
3. Criar environment (staging/prod) → POST /api/v1/projects/{id}/environments
4. Criar application              → POST /api/v1/applications
5. Configurar env vars            → PATCH /api/v1/applications/{uuid}/envs
6. Deploy                         → POST /api/v1/applications/{uuid}/deploy (tag/branch)
7. Monitorar status               → GET /api/v1/deployments/{uuid}
```

## 4. Endpoints Essenciais

| Ação               | Método | Endpoint                                           |
| ------------------ | ------ | -------------------------------------------------- |
| Listar servidores  | GET    | `/api/v1/servers`                                  |
| Criar aplicação    | POST   | `/api/v1/applications`                             |
| Deploy aplicação   | POST   | `/api/v1/applications/{uuid}/deploy`               |
| Env vars (bulk)    | PATCH  | `/api/v1/applications/{uuid}/envs`                 |
| Status deploy      | GET    | `/api/v1/deployments/{uuid}`                       |
| Start/Stop/Restart | POST   | `/api/v1/applications/{uuid}/start\|stop\|restart` |
| Criar database     | POST   | `/api/v1/databases`                                |
| Criar service      | POST   | `/api/v1/services`                                 |

## 5. Environment Variables — Dogmas

```typescript
// ✅ CERTO — bulk update com is_preview separado
const envVars = [
  {
    key: "DATABASE_URL",
    value: connString,
    is_preview: false,
    is_build_time: false,
  },
  {
    key: "NEXT_PUBLIC_API",
    value: apiUrl,
    is_preview: false,
    is_build_time: true,
  },
];

await fetch(`${COOLIFY_URL}/api/v1/applications/${uuid}/envs`, {
  method: "PATCH",
  headers: {
    Authorization: `Bearer ${process.env.COOLIFY_API_TOKEN}`,
    "Content-Type": "application/json",
  },
  body: JSON.stringify(envVars),
});

// ❌ ERRADO — env vars uma por uma (N requests)
for (const env of envVars) {
  await fetch(`${COOLIFY_URL}/api/v1/...`, { body: JSON.stringify(env) });
}
```

## 6. CI/CD com Webhooks

```yaml
# GitHub Actions — deploy automático
- name: Deploy to Coolify
  run: |
    curl -X POST "${COOLIFY_URL}/api/v1/applications/${APP_UUID}/deploy" \
      -H "Authorization: Bearer ${COOLIFY_API_TOKEN}" \
      -H "Content-Type: application/json" \
      -d '{"tag": "${{ github.sha }}"}'
```

Alternativa: habilitar webhook automático no Coolify (Settings → Git → Auto Deploy).

## 7. Segurança

- API Token com **escopo mínimo** (leitura separada de escrita).
- HTTPS obrigatório para a instância Coolify.
- Secrets nunca em `.env` commitado — usar CI/CD secrets.
- Monitorar logs de deploy para erros silenciosos.
- Backup automático de databases antes de cada deploy destrutivo.
