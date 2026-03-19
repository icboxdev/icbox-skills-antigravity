---
name: Infrastructure as Code (Terraform & AWS CDK)
description: Architect, generate, and validate Infrastructure as Code (IaC) using Terraform and AWS CDK. Enforces remote state locking, environment isolation, secrets management, and stateless/stateful stack separation.
---

# Infrastructure as Code (Terraform & AWS CDK)

Em 2024+, a gerência de Infraestrutura como Código exige salvaguardas extremas. Um `terraform apply` mal executado pode destruir bancos de dados de produção. Regras rigorosas de *State Management* e *Blast Radius* são obrigatórias.

## 🏛️ Dogmas de Arquitetura IaC

1. **PROIBA STATE FILES LOCAIS:** O arquivo `.tfstate` NUNCA deve residir na máquina do desenvolvedor ou ser commitado no Git. OBRIGATÓRIO usar *Remote Backends* (ex: AWS S3 + DynamoDB para State Locking ou Terraform Cloud). O State file contém segredos em texto plano e a falta de Locking causa corrupção se dois DEVs aplicarem ao mesmo tempo.
2. **ISOLAMENTO POR AMBIENTE (Director Structure > Workspaces):** NUNCA misture recursos de `dev` e `prod` no mesmo arquivo de estado, nem dependa exclusivamente de Terraform Workspaces para separação crítica. OBRIGATÓRIO separar fisicamente por diretórios (`envs/dev`, `envs/prod`) para isolar o "Blast Radius" (Raio de Destruição).
3. **AWS CDK: SEPARAÇÃO STATEFUL vs STATELESS:** Em AWS CDK, um erro comum é colocar o RDS (Banco) e a Lambda (App) na mesma Stack. Se a Stack for deletada ou falhar feio, o banco vai junto. OBRIGATÓRIO usar duas Stacks separadas. A `DatabaseStack` deve ter *Termination Protection* ativado e IDs lógicos estáticos e imutáveis.
4. **ZERO SECRETS NO CÓDIGO IAC:** Nunca passe senhas de banco ou API Keys declaradas nos arquivos `.tf` ou no CDK. OBRIGATÓRIO usar Data Sources/Constructs que puxam segredos resolvidos em tempo de deploy a partir do AWS Secrets Manager ou HashiCorp Vault.
5. **PIPELINE-DRIVEN DEPLOYMENTS:** Desenvolvedores não devem rodar `terraform apply` ou `cdk deploy` de suas máquinas para a produção. OBRIGATÓRIO modelar pipelines de CI/CD (GitHub Actions / CDK Pipelines) com um passo explícito de aprovação após o `terraform plan`.

## 🛑 Padrões (Certo vs Errado)

### Terraform State Management

**❌ ERRADO** (State local versionado no Git):
```hcl
# Arquivo main.tf sem declaração de backend.
# O Terraform vai gerar terraform.tfstate localmente que, se commitado, expõe secrets.
provider "aws" { region = "us-east-1" }
```

**✅ CERTO** (Remote Backend com Locking Habilitado):
```hcl
terraform {
  backend "s3" {
    bucket         = "minha-empresa-terraform-state-prod"
    key            = "core/network/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-locks" # Previne execuções concorrentes!
  }
}
```

### AWS CDK: Isolamento Stateful Lifecycle

**❌ ERRADO** (Juntar tudo numa Stack só, risco de perda de dados acidental):
```typescript
export class MonolithicAppStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);
    // Banco Risco de Drop + App Transitório juntos
    const db = new rds.DatabaseInstance(this, 'ProdDB', { ... });
    const api = new lambda.Function(this, 'ApiHandler', { ... }); 
  }
}
```

**✅ CERTO** (Stacks separadas com Proteção de Retenção):
```typescript
export class DatabaseStack extends cdk.Stack {
  public readonly dbInstance: rds.DatabaseInstance;
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, { ...props, terminationProtection: true }); // Proteção ligada!

    this.dbInstance = new rds.DatabaseInstance(this, 'ProdDB', { 
       removalPolicy: cdk.RemovalPolicy.RETAIN, // Nunca deletar o banco acidentalmente
       // ...
    });
  }
}

export class AppStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: AppStackProps) {
    super(scope, id, props);
    // Consome a Referência do Banco injetada pela DatabaseStack
    const api = new lambda.Function(this, 'ApiHandler', {
        environment: { DB_HOST: props.dbInstance.dbInstanceEndpointAddress }
    });
  }
}
```
