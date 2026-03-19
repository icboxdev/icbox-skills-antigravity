---
name: Multimodal AI Architecture (Audio, Vision, OCR)
description: Architect, generate, and optimize Multimodal AI systems. Enforces efficient Vision LLM integration for complex OCR, robust ASR pipelines (Whisper), and strict latency mitigation strategies (Token Streaming, Data Subsampling) for real-time interactions.
---

# 👁️🗣️ Multimodal AI Architecture (Audio, Vision, OCR)

This skill defines the architectural dogmas and absolute best practices for building AI systems that integrate Audio (ASR/TTS), Vision, and advanced OCR capabilities.

## 🏗️ Core Architectural Dogmas

### 1. Vision LLMs over Legacy OCR
*   **Dogma:** Traditional OCR libraries (Tesseract) fail on complex layouts, nested tables, and handwritten context.
*   **Rule:** Use Vision-capable Multimodal LLMs (e.g., GPT-4o, Claude 3.5 Sonnet Vision, LLaVA) for complex document extraction.
*   **Rule:** When prompting a Vision LLM for OCR, explicitly request bounding box coordinates or structured structured JSON/Markdown representation of the spatial layout to preserve structural intelligence.

### 2. Robust Audio Transcription (ASR with Context)
*   **Dogma:** Raw speech-to-text lacks phonetic awareness of domain-specific jargon.
*   **Rule:** When using ASR models like OpenAI Whisper, ALWAYS pass a `prompt` parameter containing a comma-separated list of expected jargon, acronyms, or proper nouns (e.g., names of employees or internal software). This drastically reduces phonetic hallucination (e.g., transcribing "React Query" as "Re-act query").
*   **Rule:** Utilize timestamped transcriptions (word-level or segment-level) to allow the frontend UI to synchronize audio playback with highlighted text.

## ⚙️ Latency Mitigation and Performance

### 1. Data Subsampling and Context Management
*   **Dogma:** Injecting a 60fps 4K video into a Vision LLM will cause massive latency and token cost blowouts.
*   **Rule:** For video analysis, implement aggressive frame subsampling (e.g., 1 frame per second, or detecting scene-change keyframes only).
*   **Rule:** Resize images to the lowest acceptable resolution that still preserves necessary details (typically 512px or 1024px longest edge) before base64 encoding or uploading to the model.

### 2. Token Streaming and Decoupled Speech
*   **Dogma:** In Voice-to-Voice conversational AI, waiting for the entire LLM response to complete before generating Text-to-Speech (TTS) creates an unacceptably delayed, robotic experience.
*   **Rule:** The LLM MUST output text natively via Streaming (Server-Sent Events).
*   **Rule:** Implement queue-based token accumulation: As soon as the streaming LLM generates the first full sentence (detected via punctuation `.` or `?`), immediately dispatch that sentence chunk to the TTS engine while the LLM continues generating the rest in the background. This drops Time-to-First-Byte audio latency to <500ms.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

