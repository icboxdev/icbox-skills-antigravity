---
name: Spring Boot 3 & Java Enterprise
description: Architect, generate, and validate enterprise Java applications using Spring Boot 3+ and Java 21+. Enforces Virtual Threads (Project Loom), GraalVM Native Image considerations, Spring Security 6 component-based config, and advanced data access.
---

# 🍃 Spring Boot 3 & Java 21+ Enterprise Architecture

This skill defines the architectural dogmas and absolute best practices for building robust, secure, and hyper-scalable enterprise backends using **Java 21+** and **Spring Boot 3.x**. It fully leverages Project Loom (Virtual Threads) and modern Spring Security patterns.

## 🏗️ Core Architectural Dogmas

### 1. Project Loom: Virtual Threads (Java 21)
*   **Dogma:** Traditional OS Platform Threads (1MB each) are obsolete for I/O-bound microservices. Java 21 Virtual Threads (1KB each, JVM-managed) allow synchronous "blocking" code to scale infinitely like Reactive code.
*   **Rule:** For any web API, enable Virtual Threads globally in `application.properties`:
  ```properties
  spring.threads.virtual.enabled=true
  ```
*   **Rule:** Virtual Threads are for **I/O-bound** workloads (Database queries, HTTP calls). Do NOT use them for heavily CPU-bound math calculations.
*   **Rule:** NEVER pool Virtual Threads. They are cheap to create and destroy per request.

### 2. Spring Security 6 Component-Based Configuration
*   **Dogma:** The old `WebSecurityConfigurerAdapter` is deprecated and removed. Security is now configured using explicit component-based beans.
*   **Rule:** Define a `SecurityFilterChain` bean. Enforce HTTPS, disable CSRF only if making a stateless REST API (using JWT/Tokens), and meticulously configure `authorizeHttpRequests`.

```java
// CERTO: Spring Security 6 Pattern
@Configuration
@EnableWebSecurity
public class SecurityConfig {
    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf(csrf -> csrf.disable()) // Only for Stateless REST APIs
            .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/auth/**").permitAll()
                .anyRequest().authenticated()
            )
            .oauth2ResourceServer(oauth2 -> oauth2.jwt(Customizer.withDefaults()));
        return http.build();
    }
}
```

### 3. GraalVM Native Image Readiness
*   **Dogma:** Spring Boot 3 natively supports compilation to AOT (Ahead-of-Time) GraalVM Native Images, reducing startup time from seconds to milliseconds and drastically cutting RAM usage.
*   **Rule:** Write code that is "Native Image Friendly". Avoid deep runtime Reflection where possible. If using dynamic proxies or reflection on non-Spring beans, you MUST register them via `@RegisterReflectionForBinding` or GraalVM hint files.

## ⚙️ Data Access and Validation

### 1. Spring Data JPA & Record Types
*   **Dogma:** Modern Java is immutable by default at the delivery layer.
*   **Rule:** Use Java 14+ `record` types for all DTOs (Data Transfer Objects). They are concise, immutable, and work perfectly with Jackson serialization.
*   **Rule:** When optimizing queries, avoid the `N+1` problem. Do not rely on `FetchType.EAGER`. Use explicit `@Query("SELECT e FROM Entity e JOIN FETCH e.relation")` or EntityGraphs to load aggregates.

### 2. Zero-Trust Input Validation
*   **Dogma:** All incoming HTTP requests are hostile.
*   **Rule:** Use `@Valid` and Jakarta Validation (`@NotNull`, `@Size`, `@Pattern`) strictly on all Controller request bodies. Hook into `@ControllerAdvice` to intercept `MethodArgumentNotValidException` and return a standardized API Error Envelope (e.g., RFC 7807 Problem Details).

## 🚨 Anti-Patterns (DO NOT DO THIS)

*   ❌ **NEVER** use `ThreadLocal` indiscriminately when running under Virtual Threads, especially if caching large objects, as thousands of virtual threads will multiply that memory footprint rapidly. Use Java 21's `ScopedValue` API for passing context securely.
*   ❌ **NEVER** wrap database transactions (`@Transactional`) around long-running network calls (like an external HTTP request). This starves the HikariCP connection pool. Keep transactions tight and DB-only.
*   ❌ **NEVER** pin a Virtual Thread. "Pinning" happens if you execute prolonged blocking I/O operations inside `synchronized` blocks or native JNI methods. Replace `synchronized` blocks with `ReentrantLock` when upgrading existing codebases to Virtual Threads.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

