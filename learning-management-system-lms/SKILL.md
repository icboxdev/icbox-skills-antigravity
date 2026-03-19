---
name: Learning Management System (LMS) Architecture
description: Architect, scale, and validate Learning Management System (LMS) platforms. Enforces Course/Module/Lesson strict hierarchy, HLS Video streaming, DRM (Digital Rights Management) protection, and event-driven progress tracking telemetry.
---

# 🎓 Learning Management System (LMS) Architecture Mastery

This skill defines the architectural dogmas and absolute best practices for building modern, scalable, and highly secure **Learning Management Systems (LMS)** or EdTech platforms.

## 🏗️ Core Architectural Dogmas

### 1. Hierarchical Content Modeling
*   **Dogma:** Do not create flat lists of videos. Education requires structure.
*   **Rule:** The data model MUST strictly enforce the hierarchy: `Course` -> `Modules` (Chapters) -> `Lessons` (Items).
*   **Rule:** A `Lesson` must be polymorphic (e.g., `VideoLesson`, `QuizLesson`, `TextLesson`, `DownloadableAction`) to allow the platform to evolve without breaking the core structure.

### 2. HLS Video Streaming & CDN Delivery
*   **Dogma:** Serving large MP4 files directly from a backend server is an architectural failure. It destroys bandwidth and prevents adaptive quality.
*   **Rule:** All videos MUST be transcoded into **HLS (HTTP Live Streaming)** format (a `.m3u8` playlist file dictating multiple `.ts` segment chunks of 5-10 seconds each).
*   **Rule:** The video player (e.g., Video.js or a native player) will dynamically negotiate resolution (1080p, 720p, 480p) based on the user's real-time internet bandwidth.
*   **Rule:** Serve all Video blobs aggressively through a CDN (Cloudflare, AWS CloudFront).

### 3. DRM (Digital Rights Management) & Piracy Prevention
*   **Dogma:** Paid educational content will be pirated if you just expose a raw MP4 or unprotected HLS URL.
*   **Rule:** Implement Video DRM (Widevine for Chrome, PlayReady for Edge, FairPlay for Safari) or HLS AES-128 minimum encryption.
*   **Rule:** The frontend video player MUST request an ephemeral decryption key from the backend API for a specific user session before the video bytes can be decrypted in the browser.
*   **Watermarking:** To prevent screen recording, burn an invisible or moving watermark (the user's email or ID) onto the video player canvas.

## ⚙️ Progress Tracking & Telemetry

### 1. The Watch-Time Telemetry Engine
*   **Dogma:** Do not rely on a simple `lesson.is_completed = true` boolean click. Users will skip videos.
*   **Rule:** The frontend Video Player MUST emit progress telemetry events (pings) every 5-10 seconds of playback (e.g., `Event(userId, lessonId, currentTimestamp)`).
*   **Rule:** The backend aggregates these pings into a `user_lesson_progress` table holding the exact percentage watched.
*   **Rule:** Buffer these high-frequency background pings through a task queue (Redis/RabbitMQ) or batch them before writing to PostgreSQL to avoid locking the primary database.

### 2. Gamification and SCORM Alternatives
*   **Dogma:** SCORM is legacy XML. Build modern event-driven architectures.
*   **Rule:** Emit granular Domain Events (e.g., `CourseCompleted`, `QuizPassed_With_Score_95`).
*   **Rule:** A separate asynchronous worker listens to these events to award Badges, Certificates, or trigger email automation, completely decoupled from the main HTTP response cycle.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

