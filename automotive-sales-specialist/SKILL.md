---
name: Automotive Sales Specialist Workflow
description: Core knowledge about the Dealership Sales Specialist persona, their daily routine, sales funnel (Lead, Test Drive, Appraisal, Closing), pain points, and CRM software requirements. Use this to design highly effective Dealership Management Systems (DMS) and Automotive CRMs.
---

# Automotive Sales Specialist — Persona & UX Dogmas

## 1. O Pipeline de Venda (Automotive Sales Funnel)

O fluxo de venda de veículos é altamente estruturado. Todo CRM Automotivo DEVE suportar este pipeline:

1. **Lead Generation/Capture**: O cliente chega via WhatsApp, Portal (WebMotors), Site Próprio ou Walk-in (presencial).
2. **Qualificação & Agendamento**: Triage rápida, o ideal é contato em < 5 minutos. Objetivo: Agendar visita.
3. **Showroom & Test Drive**: O momento crítico. O vendedor precisa do sistema na palma da mão (Mobile) no pátio para checar o estoque em tempo real.
4. **Avaliação do Usado (Appraisal)**: Inserir placa/detalhes do veículo de troca do cliente para precificação.
5. **Negociação & Desking**: Estruturar a oferta real (Valor do carro novo - Avaliação do Usado + Condições de Financiamento).
6. **Fechamento (F&I)**: Aprovação bancária, documentação e assinatura de contratos.
7. **Pós-Venda (Follow-up)**: Retenção, avisos de revisão e indicação.

## 2. A Rotina e Pain Points do Vendedor

Vendedores de carros são movidos por relacionamento e foco em comissionamento. Eles **odeiam** trabalho administrativo redundante que tira o foco da frente de loja.

### Dores Críticas (Pain Points):
- **Fragmentação de Dados (Alt-Tab)**: Ter que usar 3 sistemas diferentes (um para anúncio, um para ficha de financiamento, outro de CRM).
- **Digitação Dupla (Double Data Entry)**: Preencher os mesmos dados do cliente no CRM da loja e no sistema do banco ou na oficina.
- **Perda de Leads (Skating/Leaking)**: Esquecer de retornar um cliente por falta de alertas automáticos e visão de pipeline clara, ou perder a "autoria" do cliente em dias de folga.
- **Sistemas Desktop-Only**: A impossibilidade de registrar dados enquanto caminha no pátio mostrando o carro, forçando o uso do caderno e, posteriormente, 1h na frente do PC.

## 3. Dogmas de UX/UI para CRMs Automotivos

Ao projetar interfaces para este usuário, SIGA RÍGIDAMENTE estas regras:

- **Mobile-First Real**: O vendedor usa o celular no pátio. Formulários devem ser limpos, com selects nativos, botões grandes e leitura à luz do sol (alto contraste). Permitir escaneamento de CNH/Placa via OCR, se possível.
- **Data-Entry Minimalista (Frictionless)**: Reduza campos obrigatórios iniciais drasticamente. Use auto-complete (busca por placa via API, CEP via ViaCEP). Se houver apenas Nome e Telefone, o CRM já DEVE permitir a criação do Lead.
- **Unified Customer View 360º**: Uma única tela deve agrupar: Histórico do cliente, Carro de interesse, Troca oferecida e Timeline cronológica multicanal (WhatsApp/E-mail/Ligação).
- **Pipeline Kanban Limpo**: Visão visual do funil (Arrastar o card do cliente de "Novo Lead" para "Agendamento de Test Drive" para "Financiamento").

## 4. Anti-Patterns em Software de Concessionária

- ❌ **Obrigar preenchimento de CPF/Endereço logo no Lead Entry**: O vendedor inicial só tem o nome e WhatsApp. Exigir dados completos precocemente bloqueia o funil e gera dados lixo ("000.000.000-00", "aaa").
- ❌ **Telas com excesso de abas horizontais e formulários extensos**: Vendedores perdem o foco e a paciência. Use visão unificada cronológica (estilo timeline de rede social para histórico) e progressive disclosure em formulários.
- ❌ **Esquecer o "Lost Reason" (Motivo de Perda)**: Todo CRM deve obrigar, de forma rápida, o vendedor a justificar por que o lead esfriou (Preço, Financiamento Reprovado, Comprou Concorrente). Isso gera relatórios pro gerente comprar melhor o estoque.
- ❌ **Visão Global Sem Segregação (Em lojas médias/grandes)**: Um vendedor não deve ver os leads do outro, a menos que seja um BDC (Business Development Center) ou Gerente. Proteção de carteira de clientes é essencial.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.
