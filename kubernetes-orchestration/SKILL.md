---
name: Kubernetes Orchestration (GitOps & ArgoCD)
description: Architect, scale, and secure Kubernetes deployments enforcing GitOps principles with ArgoCD, Helm/Kustomize, External Secrets Operator (ESO), and strict Poly-Repo isolation patterns.
---

# Kubernetes Orchestration (GitOps & ArgoCD)

Em arquiteturas Kubernetes modernas (2024+), a aplicação manual usando `kubectl apply` ou CI scripts impulsivos é um anti-pattern fatal. O cluster atual deve ser reconciliado de forma declarativa e autônoma utilizando **GitOps** como fonte única da verdade.

## 🏛️ Dogmas de Arquitetura GitOps & K8s

1. **GITOPS É LEI (ArgoCD/Flux):** NADA entra no cluster via CLI interativo. OBRIGATÓRIO que o estado do cluster reflita exatamente um repositório Git. O ArgoCD deve inspecionar o Git continuamente e puxar (Pull-based) as mudanças pro cluster, impedindo configuração à deriva (Configuration Drift).
2. **POLY REPO OVER MONO REPO:** NUNCA mantenha os arquivos YAML do Kubernetes (`Deployment`, `Service`) junto com o repositório de App (Código Node/Rust). OBRIGATÓRIO usar repositórios separados (ex: `app-backend-src` e `app-backend-infra`). Isso previne loops infinitos de CI e isola permissões de quem pode codar de quem pode alterar a topologia de Produção.
3. **SEGREGAÇÃO DE AMBIENTES POR DIRETÓRIO:** Em repositórios GitOps, NUNCA gerencie Prod e Dev utilizando *branches* diferentes (ex: branch `dev` e branch `prod`). Evite o "Merge Hell". OBRIGATÓRIO usar um branch `main` único estruturado em diretórios (`/envs/dev`, `/envs/prod`) utilizando Helm Values ou Kustomize Overlays.
4. **EXTERNAL SECRETS OPERATOR (ESO):** Objetos de `Secret` do Kubernetes codificados em base64 e commitados no GitOps repo são uma falha crítica de segurança. OBRIGATÓRIO usar o ESO para puxar os segredos dinamicamente de cofres externos (AWS Secrets Manager, Vault, Azure Key Vault) não-commitados.
5. **IMMUTABLE MANIFESTS (Pinned Versions):** Ao instalar charts de Helm de terceiros (ex: Prometheus, Redis), NUNCA use a tag `latest` ou faça referência indireta. OBRIGATÓRIO pinar a versão explícita do Chart (ex: `version: 12.0.4`), blindando o cluster contra deploys autônomos falhos em upgrades invisíveis de upstream.

## 🛑 Padrões (Certo vs Errado)

### Injeção de Imagem CI/CD vs GitOps

**❌ ERRADO** (CI empurrando direto pro cluster `Push-based`):
```yaml
# github-actions.yml (Anti-pattern Push)
steps:
  - name: Build and Push Docker
    run: docker push my-app:${{ github.sha }}
  - name: Deploy to K8s
    run: kubectl set image deployment/my-app app=my-app:${{ github.sha }} # PROIBIDO
```

**✅ CERTO** (CI atualiza o GitOps Repo. ArgoCD puxa `Pull-based`):
```yaml
# github-actions.yml (Padrão GitOps)
steps:
  - name: Build and Push Docker
    run: docker push my-app:${{ github.sha }}
  - name: Update GitOps Repo Manifest
    run: |
      git clone git@github.com:empresa/infra-repo.git
      cd infra-repo
      # Usa Kustomize ou YQ para alterar a versão da imagem no yaml de dev/prod
      kustomize edit set image my-app=my-app:${{ github.sha }}
      git commit -am "chore: deploy my-app sha-${{ github.sha }}"
      git push
      # PRONTO! O ArgoCD no Kubernetes verá o commit novo e fará o deploy autônomo.
```

### Gerenciamento de Segredos no K8s

**❌ ERRADO** (Armazenar segredo fake no Git):
```yaml
# GitOps Repo: db-secret.yaml (NUNCA FAÇA ISSO)
apiVersion: v1
kind: Secret
metadata:
  name: prod-db-secret
type: Opaque
data:
  password: cGFzc3dvcmQxMjM= # "password123" em base64. Segurança zero.
```

**✅ CERTO** (Usando External Secrets Operator referenciando a Nuvem):
```yaml
# GitOps Repo: external-secret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: prod-db-secret
spec:
  refreshInterval: "1h"
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: prod-db-secret # O ESO gerará o Secret nativo do k8s com base na nuvem
  data:
  - secretKey: password
    remoteRef:
      key: prod/database/credentials # Chave que está protegida lá na AWS
      property: password
```

### Helm vs Kustomize (Onde usar)
- **Use Helm:** Para empacotar Vendor Apps brutos (Bancos, Sistemas de Monitoramento) que exigem condicionais lógicas maciças (If/Else no YAML).
- **Use Kustomize:** No Repositório GitOps para orquestrar *suas* microserviços, permitindo overrides baseados em diretório (base -> dev/prod) limpos, sem reinventar a roda com milhares de chaves complexas num arquivo `values.yaml` inchado.
