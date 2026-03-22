---
name: Coolify v4 REST API Automation
description: Integrate, validate, and orchestrate server, project, and deployment management using the Coolify v4 REST API. Enforces token-based Bearer Auth, strict UUID reference structures, stateless polling strategies for deployment tracking, and idempotency in operations.
---

# Coolify v4 REST API Automation — Diretrizes Sênior

A API REST do Coolify v4 expõe todo o controle do painel administrativo. O uso desta skill garante que as automações e integrações com o Coolify (como CI/CD profundo, health checks externos, e auto-scaling simulado) sejam feitas de forma segura e idempotente.

## 1. Zero-Trust e Autenticação (Bearer Auth)

- **Endpoints Base:** A raiz da API é obrigatória e segue o padrão estrito `https://<DOMAIN_OU_IP>/api/v1`. NENHUM endpoint fora desse escopo v1 deve ser invocado (exceto webhooks específicos de integração contínua detectados na UI).
- **Token Injection:** O Token (ex: `1|s5rnFUq0...`) obrigatoriamente trafega no Request Header: `Authorization: Bearer <TOKEN>`.
- **Secret Management:** O agente NÃO expõe a chave do Coolify acidentalmente nos logs de console. Trate retornos 401 Unauthorized com paralisia imediata e solicitação de renovação do Mestre.

## 2. Modelagem Estrutural: A Hierarquia UUID

O Coolify baseia-se em UUIDs únicos alfanuméricos randômicos para quase todas as entidades.

1. **Servers:** `GET /servers` — Retorna nós provisionados. Ex: UUID de controle como host local ou Hetzner VPS remotas.
2. **Projects:** `GET /projects` — Projetos agregam vários ambientes (Environments).
3. **Environments:** Agregam Applications, Databases e Services.
4. **Applications/Databases:** `GET /applications` etc. Estas contêm as configurações de deploy e UUIDs vitais para engatilhar as compilações.

> ⚠️ Todo roteamento e controle foca no UUID, *não* no ID inteiro da tabela do banco.

## 3. Deployment Triggers e Polling

O acionamento de um deploy é um processo não-bloqueante asíncrono. 

```bash
# ✅ CERTO — Trigger Simples de Deploy por Tag/Commit num dado Application UUID
curl -X POST "https://dash.dominio.com/api/v1/applications/YOUR-UUID/deploy" \
  -H "Authorization: Bearer \$COOLIFY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"tag": "v1.2.0"}'
```

**Regra do Polling:** Não assuma que o deploy terminou logo após o HTTP 200 do POST. O agente deve engatilhar lógicas de polling ou aguardar webhooks externos para aferir se o Container está `running`.

## 4. Manipulação de Bancos de Dados via API

- APIs que leem ou criam `databases` via painel vão retornar as connection strings. **Trate estas URIs como hiper sensíveis**. NUNCA dê output de raw JSON contendo senhas de PostgeSQL do Coolify no meio da tela a menos que explicitamente ordenado pelo usuário.

## 5. Dogmas de Pesquisa e Uso M2M

```json
/* ✅ CERTO — Sempre valide a versão do servidor antes de supor rotas exóticas */
curl -H "Authorization: Bearer $TOKEN" https://dash.domain.com/api/v1/version
// Exemplo de Retorno: "4.0.0-beta.463"
```

```javascript
// ❌ ERRADO — Chaining cego de requisições de deleção ou rebuild sem conferir o estado anterior.
// O Coolify v4 API obedece REST strict. Dar POST numa aplicação já "In Progress" causa contenção.
```

## Resumo de Resiliência

Se a API retornar HTTP 500, NÃO repita instantaneamente. Projetos no Coolify (PHP/Laravel no controller interno) podem estar aguardando travas do Docker local. Use Exponential Backoff se a automação exigir retries automáticos.
