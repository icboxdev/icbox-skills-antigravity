---
name: AI Agentic Workflows & Multi-Agent Architecture
description: Architect, generate, and validate AI Agentic Workflows. Enforces ReAct (Reason, Act) patterns, Tool Calling pipelines, graph-based state machines (LangGraph), and conversational multi-agent architectures (AutoGen) with Human-in-the-loop (HITL).
---

# 🤖 AI Agentic Workflows & Multi-Agent Architecture

This skill defines the architectural dogmas and absolute best practices for building autonomous AI agents and complex **Agentic Workflows** using frameworks like LangGraph and AutoGen.

## 🏗️ Core Architectural Dogmas

### 1. The ReAct Pattern (Reasoning + Acting)
*   **Dogma:** LLMs cannot reliably execute complex tasks in a single shot. They need to "think" before they act.
*   **Rule:** Implement the ReAct loop: `Thought` -> `Action` (Tool Call) -> `Observation` (Tool Result) -> `Thought` -> ... -> `Final Answer`.
*   **Rule:** Force the LLM to output a `thought` field in its JSON response BEFORE the `tool_calls` array. This drastically reduces hallucination and improves tool selection accuracy.

### 2. Graph-Based State Machines (LangGraph)
*   **Dogma:** Unstructured loops (e.g., standard LangChain Agents) are non-deterministic and dangerous in production.
*   **Rule:** Use state-machine based orchestrators (like LangGraph or vanilla state machines in Rust) to define explicit nodes (steps) and edges (conditional routing).
*   **Rule:** The Graph MUST maintain a typed `State` object that gets appended to (not fully overwritten) at each node.

### 3. Modularity: Specialized Agents over "CEO" Agents
*   **Dogma:** Do not build one massive prompt instructing a single agent to "Write Code, Test Code, Read DB, and Reply to User". It will degrade in intelligence.
*   **Rule:** Build small, hyper-specialized agents (e.g., "SQL Expert Agent", "Code Reviewer Agent", "Web Searcher Agent").
*   **Rule:** Use a "Supervisor" or "Router" node to delegate tasks to the appropriate specialized sub-agent.

## ⚙️ Resilience and Production Best Practices

### 1. Human-in-the-Loop (HITL) & Checkpointing
*   **Dogma:** Agents taking destructive actions (e.g., executing SQL `DROP`, transferring funds, sending bulk emails) MUST be paused.
*   **Rule:** The orchestrator must support state checkpointing. When reaching a sensitive node, pause execution, serialize state to DB, notify a human, and await a webhook/approval to resume the exact state graph.

### 2. Tool Calling Discipline
*   **Dogma:** The LLM cannot invent tool parameters.
*   **Rule:** All tools MUST be defined with strict JSON Schema (or Pydantic models).
*   **Rule:** If a tool call fails (e.g., `400 Bad Request` or generic error), catch the error, format it gracefully (`"Tool failed with: <error_msg>. Please fix your arguments and try again."`), and pass it back to the agent as an `Observation` so it can self-correct. Do not crash the graph.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

