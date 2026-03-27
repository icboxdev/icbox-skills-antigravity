---
name: LLM Evaluation, Fine-Tuning & Prompt CI/CD
description: Architect, validate, and optimize LLM pipelines. Enforces evaluation frameworks (Ragas, DeepEval), DPO/RLHF alignment, strict RAG vs. Fine-tuning boundaries, and CI/CD automated prompt testing (LLM-as-a-judge).
---

# 🧠 LLM Evaluation, Fine-Tuning & Prompt CI/CD

This skill defines the architectural dogmas and absolute best practices for evaluating Large Language Models (LLMs), optimizing them via Fine-Tuning or Alignment, and implementing continuous integration for prompts.

## 🏗️ Core Architectural Dogmas

### 1. RAG vs. Fine-Tuning Boundary
*   **Dogma:** Do not fine-tune an LLM just to teach it dynamic facts (e.g., "The company's revenue in Q3 was $5M").
*   **Rule:** Use **RAG (Retrieval-Augmented Generation)** to inject facts, documentation, and real-time data into the prompt context window.
*   **Rule:** Use **Fine-Tuning (SFT)** ONLY to change the model's behavior, tone, output format (e.g., strict custom JSON dialects), or native language reasoning (e.g., medical jargon), NOT to teach it knowledge.

### 2. DPO (Direct Preference Optimization) over RLHF
*   **Dogma:** Reinforcement Learning from Human Feedback (RLHF) with explicit Reward Models is computationally unstable and expensive for smaller teams.
*   **Rule:** When aligning an LLM to human preferences, use **DPO (Direct Preference Optimization)**. It requires only a dataset of relative preferences (Prompt -> Chosen Response vs. Rejected Response) and bypasses the need for a separate reward model.

## ⚙️ Evaluation and CI/CD Discipline

### 1. Data-Driven Evaluation (Ragas Framework)
*   **Dogma:** "Vibes" and manual chatting are not acceptable methods for evaluating an LLM application in production.
*   **Rule:** Use frameworks like `Ragas` or `DeepEval` to continuously monitor RAG pipelines.
*   **Rule:** You MUST measure:
    *   **Context Precision & Recall:** Did the Vector DB return the right chunks?
    *   **Faithfulness:** Did the LLM hallucinate answers outside of the provided context?
    *   **Answer Relevancy:** Did the LLM actually answer the user's specific question?

### 2. LLM-as-a-Judge inside CI/CD
*   **Dogma:** Changing a system prompt or a RAG chunking strategy can silently break regressions across hundreds of edge cases.
*   **Rule:** Treat prompts as code. Prompt versions MUST be tracked in Git.
*   **Rule:** On Pull Request, run an automated CI pipeline over a "Golden Dataset" of ~50-100 historical queries. Use a stronger model (e.g., GPT-4o or Claude 3.5 Sonnet) as the "Judge" to score the outputs of the PR branch against the Golden Responses using a strict grading rubric. Block the PR if the score drops.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

