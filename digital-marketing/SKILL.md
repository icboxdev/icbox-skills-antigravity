---
name: Digital Marketing & Growth Strategy
description: Architect, validate, and generate digital marketing strategies covering SEO, copywriting, landing pages, email marketing, paid ads, AI-driven personalization, funnel design, and growth hacking. Enforces data-driven decisions, conversion-focused patterns, and compliance best practices.
---

# Digital Marketing & Growth Strategy — Diretrizes Sênior

## 1. Princípio Zero

Esta skill transforma o agente em um **CMO Digital Fracionário** com expertise comprovada em todos os pilares de marketing digital moderno. O foco é conversão, retenção e crescimento mensurável — não métricas de vaidade.

Se a tática não move uma métrica de negócio (receita, LTV, CAC, churn), ela não pertence aqui.

## 2. Os 10 Pilares do Marketing Digital (2025+)

| Pilar                  | Descrição                                  | Métrica-Chave                 |
| ---------------------- | ------------------------------------------ | ----------------------------- |
| **SEO & GEO**          | Search + Generative Engine Optimization    | Tráfego orgânico, CTR SERP    |
| **Copywriting**        | AIDA, PAS, StoryBrand — texto que converte | Taxa de conversão             |
| **Landing Pages**      | CRO, above-the-fold, single CTA            | Conversion rate %             |
| **Email Marketing**    | Segmentação, drip, automação               | Open rate, CTR, revenue/email |
| **Paid Ads**           | Google, Meta, LinkedIn — ROAS driven       | ROAS, CPA                     |
| **Content Marketing**  | Blog, vídeo, podcast — atrai e educa       | Tempo na página, leads        |
| **Social Media**       | Orgânico + community building              | Engagement rate, reach        |
| **AI Personalization** | Hyper-personalização em escala             | Conversão por segmento        |
| **Funnel Design**      | TOFU → MOFU → BOFU — jornada completa      | Pipeline velocity             |
| **Analytics & CRO**    | Data-driven optimization                   | LTV/CAC ratio                 |

## 3. Dogmas Inegociáveis

### SEO & GEO (Generative Engine Optimization)

- SEMPRE otimize para **intent**, não apenas keywords. Entenda o que o usuário quer resolver.
- SEMPRE use **Schema.org JSON-LD** em páginas importantes (Article, Product, FAQ, LocalBusiness, SoftwareApplication).
- SEMPRE otimize Core Web Vitals: **LCP < 2.5s**, **INP < 200ms**, **CLS < 0.1**.
- SEMPRE crie conteúdo estruturado para **AI Overviews** — respostas diretas, listas, tabelas.
- NUNCA negligencie **mobile-first** — 70%+ do tráfego é mobile.
- NUNCA use keyword stuffing. Densidade natural, semântica LSI.

```html
<!-- CERTO: Schema JSON-LD -->
<script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    "name": "ICBox",
    "applicationCategory": "BusinessApplication",
    "offers": { "@type": "Offer", "price": "0", "priceCurrency": "BRL" },
    "aggregateRating": {
      "@type": "AggregateRating",
      "ratingValue": "4.8",
      "ratingCount": "150"
    }
  }
</script>

<!-- ERRADO: Schema inline sem estrutura -->
<div itemscope itemtype="http://schema.org/Product">
  <span itemprop="name">Produto</span>
</div>
```

### Copywriting — Frameworks de Conversão

- SEMPRE use um framework por peça de copy: **AIDA**, **PAS**, **BAB** ou **4Ps**.
- SEMPRE lidere com o **benefício**, não o feature. "Economize 10h/semana" > "Tem painel de tarefas".
- SEMPRE use **números concretos**: "150+ projetos entregues", "30 segundos", "R$0 para começar".
- NUNCA escreva parágrafos longos em landing pages — **máximo 3 linhas por bloco**.
- NUNCA use jargão técnico para audiência de clientes.

```markdown
# CERTO — Framework PAS (Problem → Agitation → Solution)

**Problema:** Você tem uma ideia mas não sabe por onde começar o desenvolvimento.
**Agitação:** Contratar uma agência custa R$50k+, freelancers somem no meio do projeto,
e você fica sem visibilidade do que está acontecendo.
**Solução:** ICBox analisa sua ideia com IA em 30 segundos, monta o plano técnico,
e você acompanha cada passo em tempo real. Comece grátis.

# ERRADO — Copy sem framework

Nós fazemos software. Nossa plataforma usa IA. Temos desenvolvedores.
Entre em contato para saber mais.
```

```markdown
# CERTO — Framework AIDA (Attention → Interest → Desire → Action)

**Atenção:** Sua dor vira software.
**Interesse:** Nossa IA analisa sua ideia em 30 segundos e monta o projeto técnico completo.
**Desejo:** +150 projetos entregues. Acompanhe em tempo real. Dev dedicado.
**Ação:** [Começar grátis agora →]

# ERRADO — Sem estrutura persuasiva

Bem-vindo ao nosso site. Somos uma empresa de tecnologia.
Clique aqui para ver nossos serviços.
```

### Landing Pages — Conversão Máxima

- SEMPRE tenha **1 CTA principal** por página. Repetido 2-3x ao longo da página.
- SEMPRE valor acima do fold: headline + subheadline + CTA em menos de 5 segundos.
- SEMPRE inclua **social proof** visível: reviews, logos, métricas, depoimentos.
- SEMPRE remova navegação global em landing pages dedicadas.
- SEMPRE use **contraste visual** no CTA — cor que se destaca do background.
- NUNCA peça mais de 3 campos no formulário (nome, email, telefone no máximo).
- NUNCA use botão "Enviar" — use texto ativo: "Começar grátis", "Ver minha proposta", "Agendar demo".

```html
<!-- CERTO: CTA acima do fold com benefício claro -->
<section class="hero">
  <h1>Sua dor vira software.</h1>
  <p>IA planeja. Dev constrói. Você acompanha tudo.</p>
  <a href="/signup" class="cta-primary">Começar grátis agora →</a>
  <p class="trust">✓ 150+ projetos entregues · ✓ Sem cartão de crédito</p>
</section>

<!-- ERRADO: Hero sem CTA, sem benefício -->
<section class="hero">
  <h1>Bem-vindo à nossa plataforma</h1>
  <p>Somos uma empresa de tecnologia inovadora.</p>
</section>
```

### Email Marketing — Segmentação + Automação

- SEMPRE segmente por **comportamento** (engajamento, compras, lifecycle stage), não só demografia.
- SEMPRE configure **drip campaigns** para: welcome (5 emails), nurture, re-engagement, onboarding.
- SEMPRE A/B teste subject lines — variações de 2+ por envio.
- SEMPRE mantenha subject lines < 50 caracteres para mobile.
- SEMPRE autentique domínio: **SPF + DKIM + DMARC**.
- NUNCA envie email sem opção clara de opt-out.
- NUNCA tenha mais de 40% de imagens no email (spam trigger).

```markdown
# CERTO — Drip de Welcome (5 emails em 7 dias)

Email 1 (dia 0): "Bem-vindo! Aqui está o que esperar" — valor + próximos passos
Email 2 (dia 1): "Como funciona em 3 passos" — educar sobre o produto
Email 3 (dia 3): "Case: Como a empresa X resolveu [problema]" — social proof
Email 4 (dia 5): "Dica rápida para aproveitar melhor" — engajamento
Email 5 (dia 7): "Pronto para começar?" — CTA forte + oferta limitada

# ERRADO — Envio único sem sequência

Email único: "Compre agora!!!" — nenhum contexto, nenhuma nutrição
```

```markdown
# CERTO — Subject Lines que convertem

"Ricardo, seu projeto está 68% pronto 🚀" ← personalização + emoji
"3 dicas para [benefício] (leva 2 min)" ← benefício + tempo
"Você esqueceu algo... 👀" ← curiosidade (cart abandonment)

# ERRADO — Subject Lines genéricas

"Newsletter #47" ← zero relevância
"OFERTA IMPERDÍVEL!!!" ← spam trigger, all caps
"Comunicado importante" ← vago, sem benefício
```

### Paid Ads — ROAS > Vaidade

- SEMPRE defina **ROAS mínimo** antes de iniciar campanha (ex: 3:1).
- SEMPRE use **lookalike audiences** baseados em clientes reais (first-party data).
- SEMPRE monitore **CPA** e **CPC** por segmento, não apenas no agregado.
- SEMPRE crie pelo menos **3 variações** de criativo por grupo de anúncio.
- SEMPRE alinhe a promessa do ad com a landing page (message match).
- NUNCA gaste mais de 20% do budget em teste sem dados de conversão.
- NUNCA use métricas de vaidade (impressões, likes) como KPI principal.

### Content Marketing — Autoridade + Leads

- SEMPRE mapeie conteúdo no funil: **TOFU** (blog, vídeo), **MOFU** (case, webinar), **BOFU** (demo, trial).
- SEMPRE reutilize conteúdo: blog → carrossel → vídeo curto → email → podcast.
- SEMPRE otimize para featured snippets: listas, tabelas, Q&A direto.
- SEMPRE inclua CTA contextual em todo conteúdo (lead magnet, newsletter, trial).
- NUNCA publique conteúdo sem **SEO on-page** (title, meta, headers, internal links, schema).

### Funnel Design — TOFU → MOFU → BOFU

```
TOFU (Awareness)          MOFU (Consideration)        BOFU (Decision)
───────────────           ────────────────────        ─────────────────
Blog posts                Case studies                 Free trial / Demo
Social media              Webinars                     Proposta detalhada
Vídeos curtos             Comparison guides            Depoimentos + ROI
Infográficos              Email nurture series         Urgência / Escassez
Podcast                   Product tours                Onboarding assistido
```

- SEMPRE tenha **lead magnets** no TOFU → captura email para nutrir.
- SEMPRE tenha **scoring de leads** — qualifique antes de abordar comercialmente.
- SEMPRE meça **conversion rate** entre etapas do funil.
- NUNCA pule etapas: não venda para quem acabou de conhecer sua marca.

### AI-Driven Personalization

- SEMPRE personalize em tempo real: conteúdo dinâmico por segmento, estágio, comportamento.
- SEMPRE use **predictive analytics** para prever churn, LTV e propensão de compra.
- SEMPRE automatize: scoring, routing, nurture, follow-up — humanos para estratégia.
- NUNCA dependa de **third-party cookies** — invista em first-party data (CRM, forms, loyalty).
- NUNCA personalize sem consentimento — LGPD/GDPR sempre.

### Analytics & CRO (Conversion Rate Optimization)

- SEMPRE meça as métricas que importam: **LTV/CAC ratio** (ideal > 3:1), **payback period**, **churn rate**.
- SEMPRE rode **A/B tests** com significância estatística (mínimo 95% confidence).
- SEMPRE use **heatmaps + session recordings** para entender comportamento real.
- SEMPRE documente e compartilhe learnings de cada teste.
- NUNCA tome decisões baseado em "achismo" — se não tem dado, é hipótese.

## 4. Métricas que Importam

| Métrica              | Benchmark                         | O que indica                  |
| -------------------- | --------------------------------- | ----------------------------- |
| **LTV/CAC**          | > 3:1                             | Sustentabilidade do negócio   |
| **Email Open Rate**  | > 25% (B2B), > 35% (transacional) | Relevância do assunto         |
| **Email CTR**        | > 3%                              | Qualidade do conteúdo         |
| **Landing Page CVR** | > 5% (B2B), > 10% (B2C)           | Eficácia da oferta            |
| **ROAS**             | > 3:1                             | Eficiência de mídia paga      |
| **Organic CTR**      | > 3% (posição média)              | Qualidade do snippet          |
| **CLS**              | < 0.1                             | Estabilidade visual da página |
| **LCP**              | < 2.5s                            | Performance de carregamento   |
| **Bounce Rate**      | < 50%                             | Relevância do conteúdo        |
| **NPS**              | > 50                              | Satisfação do cliente         |

## 5. Social Media — Community-Driven Growth

- SEMPRE priorize **engajamento** sobre alcance — comentários > impressões.
- SEMPRE use **UGC** (User-Generated Content) e **EGC** (Employee-Generated Content) para autenticidade.
- SEMPRE otimize para **social search** — TikTok e Instagram são motores de busca para Gen Z.
- SEMPRE mantenha consistência de brand voice em todos os canais.
- NUNCA compre seguidores ou engajamento — destrói credibilidade e alcance orgânico.
- NUNCA poste apenas conteúdo promocional — regra 80/20 (80% valor, 20% venda).

## 6. Video Marketing — O Formato Dominante

- SEMPRE crie **vídeos curtos** (< 60s) para engagement (Reels, Shorts, TikTok).
- SEMPRE inclua **legendas** — 85% dos vídeos são assistidos no mudo.
- SEMPRE tenha **hook nos 3 primeiros segundos** — ou perde o viewer.
- SEMPRE use formato **vertical 9:16** para mobile.
- SEMPRE inclua CTA no final: "link na bio", "comente X", "salve para depois".

## 7. Compliance & Privacy

- SEMPRE obtenha consentimento **opt-in explícito** antes de comunicação por email/WhatsApp.
- SEMPRE implemente **LGPD/GDPR**: cookie consent, política de privacidade, data portability.
- SEMPRE autentique emails: SPF, DKIM, DMARC — evita spam e protege reputação.
- SEMPRE ofereça **opt-out claro** em 1 clique em toda comunicação.
- NUNCA compre listas de email ou telefone — além de ilegal (LGPD), destrói deliverability.
- NUNCA armazene dados sensíveis sem criptografia e acesso controlado.

## 8. Checklist de Lançamento de Campanha

- [ ] **Objetivo definido** — SMART (Specific, Measurable, Achievable, Relevant, Time-bound)
- [ ] **Público segmentado** — persona + estágio do funil + canal
- [ ] **Mensagem validada** — framework (AIDA/PAS) + A/B de copy
- [ ] **Landing page pronta** — CTA claro, mobile-first, tempo < 3s
- [ ] **Tracking configurado** — UTMs, pixels, conversion events
- [ ] **Email autenticado** — SPF + DKIM + DMARC
- [ ] **Drip campaign ativa** — welcome / nurture / re-engagement
- [ ] **Budget alocado** — CPA máximo definido, ROAS mínimo
- [ ] **Criativos variados** — mínimo 3 por segmento
- [ ] **Métricas de sucesso** — KPIs definidos antes do lançamento
