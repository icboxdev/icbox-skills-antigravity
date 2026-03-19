---
name: Antigravity Workflow Creation
description: Engineer, validate, and structure autonomous Agentic Workflows for the Antigravity agent. Enforces strict YAML frontmatter, step-by-step markdown instructions, and the precise application of `// turbo` and `// turbo-all` autonomous execution markers without hallucinations.
---

# Antigravity Workflow Creation Dogmas

You are an expert Automation Engineer for AI Agents. When asked to create a new "Workflow" (or "Fluxo") for the Antigravity system, you MUST follow these immutable architectural rules. Workflows are interactive scripts that allow the AI agent to orchestrate `run_command` tools and scaffold projects autonomously.

## 1. File Structure and Location
- ALL workflows MUST be created as `.md` files using the `write_to_file` tool.
- Workflows MUST be saved exclusively in the `~/.gemini/antigravity/.agent/workflows/` directory (use absolute paths).
- Workflows MUST contain a YAML frontmatter block at the very top of the file.

### ❌ ERRADO (Without Frontmatter or Wrong Path)
```markdown
# My Workflow
1. Run `cargo new`
```

### ✅ CERTO (Strict Layout)
```markdown
---
description: Inicializa um projeto Rust com boilerplate padronizado.
---
# Setup Application
Siga rigorosamente os passos abaixo para iniciar a API:

1. Execute a criação da aplicação e entre na pasta: `cargo new xyz && cd xyz`.
```

## 2. Autonomous Execution Constraints (`// turbo`)
The defining feature of Antigravity workflows is their ability to execute terminal commands autonomously without waiting for human approval. This is controlled via specific annotations.

- **Selective Autonomy:** Use the `// turbo` annotation EXACTLY one line above a specific workflow step if you want that specific step to instruct the agent to set `SafeToAutoRun: true` in the `run_command` tool.
- **Global Autonomy:** Use the `// turbo-all` annotation anywhere in the document if you want EVERY step involving `run_command` to be auto-run unconditionally.

### ❌ ERRADO (Unsafe Auto-Run expectations without marker)
```markdown
1. Delete the database: `rm -rf /var/lib/postgresql`
2. Create a folder: `mkdir test`
```
*Why it's wrong: The agent will prompt the user for BOTH steps, defeating the purpose of an automated workflow.*

### ✅ CERTO (Explicit Turbo Markers)
```markdown
// turbo
1. Crie a pasta do projeto e inicie o Git: `mkdir app && cd app && git init`

2. Delete arquivos remanescentes antigos se houverem: `rm -rf tmp/`
```
*Why it's right: The agent will safely execute step 1 autonomously, but will pause to ask for human permission on the potentially destructive step 2.*

## 3. Workflow Design Principles (Zero-Trust)
- **Granularity:** Break complex commands into multiple numbered steps. Do not chain 15 commands together with `&&` if they can fail independently.
- **Dependency Checking:** Before long operations, workflows should instruct the agent to verify if tools (like `docker`, `cargo`, `gh`) exist.
- **User Intention:** Avoid `// turbo-all` if the workflow does destructive actions (e.g., `git reset --hard`, `drop database`). Reserve `// turbo` for scaffolding and read-only or initialization actions.
- **Context Management:** A workflow step can explicitly ask the agent to read other skills using `view_file` (e.g. "Leia a skill `rust-lang` antes de prosseguir").

## 4. Interaction Model
When the user executes a workflow (e.g., via `/deploy`), the AI agent reads the `.md` file and executes the numbered list. Ensure the language used in the workflow is imperative directed at the AI agent itself (e.g., "Rodar o linter", "Perguntar ao usuário o nome da variável").

### ✅ CERTO (Guiding the Agent)
```markdown
---
description: Deploy da aplicação via Coolify
---
1. Execute `git log -1` para confirmar o último commit.
2. Atualize o `ROADMAP.md` movendo as tarefas para concluídas usando a ferramenta `multi_replace_file_content`.
3. Notifique o usuário sobre o envio iminente e, se aprovado, rode `git push origin main`.
```
