---
name: Financial Management System (ERP Financeiro)
description: Architect, validate, and generate financial management modules covering double-entry bookkeeping, chart of accounts, accounts receivable/payable, cash flow, bank reconciliation, invoicing, tax management, DRE reporting, and Brazilian payment integrations (PIX, boleto, NF-e). Enforces accounting integrity, multi-tenant isolation, and audit trail patterns.
---

# Financial Management System — Diretrizes de Engenharia

## 1. Princípio Fundamental: Integridade Contábil

Todo sistema financeiro DEVE garantir **integridade contábil absoluta**. Cada transação financeira segue o princípio de **partidas dobradas** (double-entry bookkeeping): todo débito tem um crédito correspondente, e vice-versa. A soma de todos os lançamentos de uma transação DEVE ser zero.

> Se o saldo não fecha, o sistema está quebrado. Não existe "quase correto" em contabilidade.

## 2. Modelo de Dados Canônico

### 2.1 Entidades Core (obrigatórias)

```
┌─────────────────────────────────────────────────────┐
│                  CHART OF ACCOUNTS                  │
│  (Plano de Contas hierárquico)                      │
├─────────────────────────────────────────────────────┤
│  id, code, name, type, parent_id, level, is_active  │
│  type: ASSET | LIABILITY | EQUITY | REVENUE | EXPENSE│
└────────────┬────────────────────────────────────────┘
             │
┌────────────▼────────────────────────────────────────┐
│                    TRANSACTIONS                      │
│  (Transações financeiras)                            │
├─────────────────────────────────────────────────────┤
│  id, date, description, reference, status, tenant_id │
│  status: DRAFT | POSTED | VOIDED                     │
└────────────┬────────────────────────────────────────┘
             │
┌────────────▼────────────────────────────────────────┐
│                  JOURNAL ENTRIES                      │
│  (Lançamentos contábeis — partidas dobradas)         │
├─────────────────────────────────────────────────────┤
│  id, transaction_id, account_id, type, amount        │
│  type: DEBIT | CREDIT                                │
│  CONSTRAINT: SUM(debits) = SUM(credits) per tx       │
└─────────────────────────────────────────────────────┘
```

### 2.2 Entidades Comerciais

```
CUSTOMERS ──► INVOICES ──► INVOICE_ITEMS
                  │
                  ▼
          RECEIVABLES (Contas a Receber)
                  │
                  ▼
          PAYMENTS_RECEIVED

SUPPLIERS ──► BILLS ──► BILL_ITEMS
                  │
                  ▼
          PAYABLES (Contas a Pagar)
                  │
                  ▼
          PAYMENTS_MADE
```

### 2.3 Entidades Bancárias

```
BANK_ACCOUNTS ──► BANK_TRANSACTIONS
                        │
                        ▼
              RECONCILIATION_RECORDS
                  (Conciliação Bancária)
```

## 3. Dogmas Arquiteturais

### 3.1 Partidas Dobradas — INEGOCIÁVEL

```typescript
// ✅ CERTO — Toda transação tem débitos = créditos
async function createTransaction(entries: JournalEntry[]): Promise<Transaction> {
  const totalDebits = entries
    .filter(e => e.type === 'DEBIT')
    .reduce((sum, e) => sum + e.amount, 0);

  const totalCredits = entries
    .filter(e => e.type === 'CREDIT')
    .reduce((sum, e) => sum + e.amount, 0);

  if (Math.abs(totalDebits - totalCredits) > 0.001) {
    throw new BalanceError('Débitos e créditos não fecham');
  }

  return db.transaction(async (tx) => {
    const transaction = await tx.insert(transactions).values({ ... });
    await tx.insert(journalEntries).values(
      entries.map(e => ({ ...e, transactionId: transaction.id }))
    );
    return transaction;
  });
}

// ❌ ERRADO — Lançamento simples sem partida dobrada
async function createTransaction(accountId: string, amount: number) {
  await db.insert(transactions).values({ accountId, amount });
  // PROIBIDO: não tem contrapartida, quebra integridade contábil
}
```

### 3.2 Imutabilidade de Lançamentos

```typescript
// ✅ CERTO — Estornar (void) ao invés de deletar
async function voidTransaction(id: string): Promise<void> {
  const original = await db.query.transactions.findFirst({ where: eq(id) });
  if (original.status === 'VOIDED') throw new Error('Já estornada');

  await db.transaction(async (tx) => {
    // Marca original como VOIDED
    await tx.update(transactions).set({ status: 'VOIDED' }).where(eq(id));

    // Cria lançamento reverso
    const reverseEntries = original.entries.map(e => ({
      ...e,
      type: e.type === 'DEBIT' ? 'CREDIT' : 'DEBIT',
    }));
    await createTransaction(reverseEntries); // estorno
  });
}

// ❌ ERRADO — Deletar ou editar lançamento contábil
await db.delete(transactions).where(eq(id));
await db.update(journalEntries).set({ amount: newAmount });
// PROIBIDO: viola trilha de auditoria
```

### 3.3 Valores Monetários — Decimal, NUNCA Float

```typescript
// ✅ CERTO — Usar Decimal / integer (centavos) para dinheiro
// No banco: DECIMAL(15,2) ou BIGINT (centavos)
// No código: libraries como Decimal.js ou armazenar em centavos

const priceInCents = 19990; // R$ 199,90
const formatted = (priceInCents / 100).toFixed(2);

// Schema Prisma
model Transaction {
  amount Decimal @db.Decimal(15, 2)
}

// ❌ ERRADO — Float para dinheiro
const price = 199.90; // PERDE PRECISÃO!
const total = 0.1 + 0.2; // 0.30000000000000004
```

### 3.4 Audit Trail Obrigatório

```typescript
// ✅ CERTO — Todo registro financeiro tem auditoria
model JournalEntry {
  id          String   @id @default(uuid())
  // ... campos de negócio ...
  createdBy   String   // quem criou
  createdAt   DateTime @default(now())
  // NUNCA updatedAt em lançamentos — são imutáveis
}

model AuditLog {
  id        String   @id @default(uuid())
  entity    String   // 'transaction', 'payment', 'invoice'
  entityId  String
  action    String   // 'created', 'voided', 'reconciled'
  userId    String
  metadata  Json?
  createdAt DateTime @default(now())
}
```

## 4. Módulos Funcionais

### 4.1 Contas a Receber (Accounts Receivable)

| Funcionalidade | Obrigatório | Descrição |
|---|---|---|
| Emissão de faturas | ✅ | Criar faturas com itens, impostos, descontos |
| Parcelamento | ✅ | Dividir em N parcelas com vencimentos |
| Baixa automática | ✅ | Conciliar pagamento recebido com fatura |
| Aging report | ✅ | Relatório de inadimplência por faixa de atraso |
| Juros/Multa automáticos | ⚡ | Calcular encargos por atraso |
| Envio de cobrança | ⚡ | Email/WhatsApp com boleto/PIX |

### 4.2 Contas a Pagar (Accounts Payable)

| Funcionalidade | Obrigatório | Descrição |
|---|---|---|
| Registro de despesas | ✅ | Categorizar por plano de contas |
| Aprovação/Workflow | ⚡ | Fluxo de aprovação por alçada |
| Pagamento em lote | ⚡ | Agrupar pagamentos para processamento |
| Recorrência | ✅ | Despesas fixas mensais automáticas |

### 4.3 Fluxo de Caixa (Cash Flow)

| Funcionalidade | Obrigatório | Descrição |
|---|---|---|
| Fluxo realizado | ✅ | Entradas/saídas efetivadas |
| Fluxo previsto | ✅ | Projeção baseada em contas a pagar/receber |
| Saldo projetado | ✅ | Previsão de saldo futuro por período |
| Categorização | ✅ | Agrupar por centro de custo/categoria |

### 4.4 Conciliação Bancária

| Funcionalidade | Obrigatório | Descrição |
|---|---|---|
| Importação OFX/CSV | ✅ | Ler extratos bancários padronizados |
| Match automático | ⚡ | Sugerir conciliações por valor/data |
| Match manual | ✅ | Usuário confirma ou associa manualmente |
| Saldo pendente | ✅ | Diferença entre registros e extrato |

### 4.5 Relatórios Financeiros

| Relatório | Sigla | Descrição |
|---|---|---|
| Demonstrativo de Resultado | DRE | Receitas - Despesas = Lucro/Prejuízo |
| Balanço Patrimonial | BP | Ativos = Passivos + Patrimônio Líquido |
| Fluxo de Caixa | DFC | Método direto ou indireto |
| Extrato por conta | - | Movimentação detalhada por conta |
| Razão contábil | - | Livro razão por conta do plano |

## 5. Integrações Brasil (🇧🇷)

### 5.1 Meios de Pagamento

```typescript
// Boleto Bancário
interface BoletoConfig {
  bankCode: string;      // Ex: '001' (BB), '341' (Itaú)
  walletCode: string;    // Carteira
  covenant: string;      // Convênio
  agencyNumber: string;
  accountNumber: string;
}

// PIX
interface PixConfig {
  key: string;          // CPF, CNPJ, email, phone, EVP
  keyType: 'cpf' | 'cnpj' | 'email' | 'phone' | 'evp';
  merchantName: string;
  merchantCity: string;
}

// QR Code PIX — Padrão BR Code
function generatePixPayload(amount: number, txId: string): string {
  // Seguir especificação BACEN BR Code
  // EMV® Qrcode Specification for Payment Systems
}
```

### 5.2 Nota Fiscal Eletrônica (NF-e)

```typescript
interface NFeIntegration {
  // Emissão via API (ex: Focus NFe, Enotas, NFe.io)
  provider: 'focus_nfe' | 'enotas' | 'nfe_io';
  environment: 'production' | 'homologation';
  certificate: {
    pfxPath: string; // A1 certificate
    password: string;
  };
  // Dados obrigatórios
  emitter: { cnpj: string; ie: string; razaoSocial: string };
}
```

### 5.3 Conciliação Bancária — OFX

```typescript
// ✅ CERTO — Parser OFX padronizado
interface OFXTransaction {
  fitId: string;      // ID único do banco
  type: 'DEBIT' | 'CREDIT';
  datePosted: Date;
  amount: number;     // em centavos
  memo: string;
  checkNum?: string;
}

// Algoritmo de match automático
function autoReconcile(
  bankTxs: OFXTransaction[],
  systemTxs: SystemTransaction[]
): ReconciliationSuggestion[] {
  return bankTxs.map(bankTx => {
    const match = systemTxs.find(sysTx =>
      Math.abs(sysTx.amount - bankTx.amount) < 0.01 &&
      daysBetween(sysTx.date, bankTx.datePosted) <= 3
    );
    return { bankTx, systemTx: match, confidence: match ? 0.9 : 0 };
  });
}
```

## 6. Plano de Contas Padrão (Brasil)

```
1. ATIVO
  1.1 Ativo Circulante
    1.1.1 Caixa e Equivalentes
    1.1.2 Bancos Conta Movimento
    1.1.3 Contas a Receber
    1.1.4 Estoques
  1.2 Ativo Não Circulante
    1.2.1 Imobilizado
    1.2.2 Intangível

2. PASSIVO
  2.1 Passivo Circulante
    2.1.1 Fornecedores
    2.1.2 Obrigações Trabalhistas
    2.1.3 Obrigações Tributárias
    2.1.4 Empréstimos CP
  2.2 Passivo Não Circulante
    2.2.1 Empréstimos LP

3. PATRIMÔNIO LÍQUIDO
  3.1 Capital Social
  3.2 Reservas
  3.3 Lucros/Prejuízos Acumulados

4. RECEITAS
  4.1 Receita de Vendas
  4.2 Receita de Serviços
  4.3 Receitas Financeiras
  4.9 Deduções da Receita

5. DESPESAS / CUSTOS
  5.1 Custo das Mercadorias Vendidas (CMV)
  5.2 Despesas Operacionais
  5.3 Despesas Administrativas
  5.4 Despesas Financeiras
  5.5 Impostos sobre Lucro
```

## 7. Constraints — NUNCA Fazer

- ❌ NUNCA usar `FLOAT` ou `DOUBLE` para valores monetários — usar `DECIMAL(15,2)` ou centavos em `BIGINT`
- ❌ NUNCA permitir DELETE em lançamentos contábeis — apenas estorno (void)
- ❌ NUNCA criar transação sem partida dobrada (débito = crédito)
- ❌ NUNCA permitir edição de transação `POSTED` — criar estorno + novo lançamento
- ❌ NUNCA armazenar dados de cartão de crédito no banco — usar tokenização via gateway
- ❌ NUNCA calcular saldo de conta sem considerar TODOS os lançamentos — derivar do ledger, nunca cache
- ❌ NUNCA gerar NF-e em produção sem certificado A1 válido
- ❌ NUNCA confiar em webhook de pagamento sem verificação de assinatura (HMAC)
- ❌ NUNCA expor chave PIX ou dados bancários em logs ou respostas de API

## 8. Multi-Tenancy Financeiro

```typescript
// ✅ CERTO — Isolamento total por tenant
// Toda query financeira DEVE filtrar por tenant_id
const receivables = await db.query.invoices.findMany({
  where: and(
    eq(invoices.tenantId, currentTenant.id), // OBRIGATÓRIO
    eq(invoices.status, 'PENDING'),
  ),
});

// ✅ CERTO — RLS no PostgreSQL para segurança extra
// CREATE POLICY tenant_isolation ON transactions
//   USING (tenant_id = current_setting('app.current_tenant')::uuid);
```

## 9. KPIs Financeiros (Dashboard)

| KPI | Fórmula | Frequência |
|---|---|---|
| Receita Bruta | SUM(receitas do período) | Diário |
| Receita Líquida | Receita Bruta - Deduções - Impostos | Mensal |
| Inadimplência (%) | Vencidos / Total a Receber × 100 | Diário |
| Ticket Médio | Receita / Nº de vendas | Semanal |
| Burn Rate | Despesas fixas mensais | Mensal |
| Runway | Caixa disponível / Burn Rate | Mensal |
| Margem Operacional | Lucro Operacional / Receita Líquida × 100 | Mensal |
| DSO (Days Sales Outstanding) | (Recebíveis / Receita) × Dias | Mensal |
| DPO (Days Payable Outstanding) | (Pagáveis / CMV) × Dias | Mensal |

## 10. Stack Recomendada

| Camada | Tecnologia | Justificativa |
|---|---|---|
| Backend | NestJS / AdonisJS / Fastify | TypeScript strict, DI, validação |
| ORM | Prisma / Lucid | Typed queries, migrations |
| Banco | PostgreSQL | DECIMAL nativo, CTEs, RLS |
| Cache | Redis | Session, rate limiting |
| Pagamentos | Asaas / PagSeguro / Stripe | Gateway com boleto + PIX |
| NF-e | Focus NFe / Enotas API | Emissão automatizada |
| Filas | BullMQ / RabbitMQ | Processamento assíncrono de boletos/NF-e |
| Frontend | React + Shadcn / Vue + PrimeVue | Dashboards, tabelas, formulários |

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

