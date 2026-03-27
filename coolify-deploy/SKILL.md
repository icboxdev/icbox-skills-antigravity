---
name: Coolify v4 Architecture & Deploy
description: Architect, generate, and validate deployments in Coolify v4. Covers Nixpacks, Traefik proxy routing, Docker Compose as the source of truth, persistent storage volumes, Database automated backups, GitHub App CI/CD, and strict Port Mapping dogmas.
---

# Coolify v4 Architecture & Deploy — Diretrizes Sênior

A versão 4 do Coolify representa uma mudança arquitetural drástica (escrita em Laravel) com foco em **GitOps**, **Nixpacks** e **Traefik** como proxy reverso padrão.

## 1. Zero-Trust & Single Source of Truth

- O Arquivo `docker-compose.yml` é considerado a **Fonte Única de Verdade (Single Source of Truth)**. Configurações que tradicionalmente residiam puramente na UI agora devem refletir a estrutura do Compose.
- **NUNCA** modifique o `docker-compose.yml` base do Coolify diretamente (ele será sobrescrito em atualizações). Se o projeto exigir personalização profunda na esteira, use um `docker-compose.override.yml`.
- Para transformar código-fonte em Imagens Docker, o Coolify delega a função ao **Nixpacks** por padrão, eliminando a criação manual de Dockerfiles (exceto se explicitamente exigido).

## 2. Proxies e Port Mapping — DOGMA CRÍTICO

O Coolify usa o **Traefik** para expor as aplicações via HTTP/HTTPS na porta 80/443. Serviços expostos recebem um domínio (FQDN).

> ⚠️ O erro mais comum em Coolify v4 ocorre no mapeamento de portas TCP customizadas (ex: Modbus, MQTT, WebSocket server) devido à sintaxe do Docker.

### Port Mappings (Host ➡️ Container)

Quando você precisa ignorar o Traefik e mapear portas diretamente (`Ports Exposes`), aplique as regras estritas da sintaxe do Docker:

```yaml
# ✅ CERTO — Expõe a porta 3000 do host para a 3000 do container
ports:
  - "3000:3000"

# ✅ CERTO — Range Numérico de Portas (usa HÍFEN, NÃO dois-pontos)
ports:
  - "5000-5099:5000-5099"
```

```yaml
# ❌ ERRADO — Isso NÃO mapeia 100 portas. O Docker entende
# que a porta host 5000 deve ser roteada para a porta interna 5099!
ports:
  - "5000:5099" 
```

**Interface Web do Coolify:** Nunca preencha "Port Mappings" com ranges usando ':'. Sempre use `-` (Hífen).

## 3. Persistent Storage (Volumes)

Para dados com estado (Arquivos estáticos, SQLite, Bancos de Dados locais):

- **Volumes (Padrão e Recomendado):** Você mapeia a pasta do container (ex: `/app/storage`). O Coolify atribui um UUID único ao nome do volume para evitar colisões entre projetos na mesma máquina.
- **Bind Mounts:** Requer definir explicitamente Host Path e Container Path. Não compartilhe entre aplicações ativas simultaneamente (exceções requerem locking).
- Em cenários de preview builds (PRs), atente-se de que volumes não migram o Storage de produção para o preview por default.

## 4. Integrações de Deploy (CI/CD)

Coolify v4 permite CI/CD 100% autônomo. O uso restrito de API REST para Trigger de Deploy é _Legacy_, embora mantido.

### GitHub App (Recomendado)
Sempre sugira ao usuário autenticar seu Coolify como "GitHub App". Assim que o escopo de Push é detectado:
1. O Coolify configura os webhooks automaticamente de ponta a ponta.
2. Cada Git Push no repositório atrelado gera um novo Docker Image via Nixpacks.
3. PRs emitem Deploy Previews exclusivos (com rotas temporárias) fechando-se automaticamente no Merge.

### API REST (Alternativa)
Se via API REST for inevitável, utilize o bearer token e acione pelo Endpoint V1 (ainda suportado):
```bash
curl -X POST "https://coolify.dominio.com/api/v1/applications/{UUID}/deploy" \
  -H "Authorization: Bearer ${COOLIFY_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"tag": "commit-sha"}'
```

## 5. Bancos de Dados e Backups

O Coolify v4 provisiona bancos de dados sob demanda e suporta internamente PostgreSQL, Redis, MySQL e outros.

- **Conectividade:** Serviços na mesma rede `coolify` devem conectar via **Internal URL** (ex: `postgres://user:pass@postgresql:5432/db`). Jamais trafegue dados não isolados pelas portas expostas da Internet Pública em projetos na mesma infraestrutura.
- **Backups Autogerenciados:** Bancos produtivos exigem Backups configurados pelo Cron do Coolify. Utilize S3 compatíveis (AWS, Cloudflare R2, Minio) nativamente pelo painel de Database do serviço provisionado.
- Utilize `pg_dump` padrão suportado por baixo dos panos pelo Coolify no caso do Postgres.

## 6. Nixpacks

Ao auditar código para deploy Nixpacks, observe que para alguns cenários você precisa providenciar metadados:

```toml
# nixpacks.toml (Opcional — define build exato)
[phases.setup]
nixPkgs = ["...', 'nodejs-18_x']

[phases.build]
cmds = ['npm run build']

[start]
cmd = 'npm run start'
```

Isso garante que o buildpack instale as extensões adequadas sem demandar scripts de `bash` ad-hoc.
