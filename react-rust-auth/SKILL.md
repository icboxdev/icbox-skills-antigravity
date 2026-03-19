---
name: React & Rust Authentication Integration
description: Architect, validate, and enforce authentication flows between React (SPA) and Rust (Axum/Actix). Imposes HttpOnly cookie-based session/token storage, Axum middleware for JWT extraction, Axios interceptors for 401 handling, and CSRF protection via SameSite=Lax.
---

# React & Rust (Axum) Authentication Integration — Diretrizes Sênior+

## 1. Princípio Zero: Proteção contra XSS e CSRF
O backend em Rust DEVE controlar as sessões e tokens sensíveis. O frontend em React DEVE atuar como um cliente que consome permissões e dados. **NUNCA armazene Refresh Tokens ou Credentials puras no `localStorage`**. Sempre use Cookies `HttpOnly` para tokens duradouros.

> ⚠️ **Crime**: Armazenar Refresh Tokens no `localStorage` do React. Um simples ataque de XSS seria capaz de roubar o token e dar acesso vitalício e invisível ao atacante.

## 2. Padrão Backend (Axum): Entrega Segura de Cookies
Sempre utilize cookies com as flags `HttpOnly`, `Secure` e `SameSite=Lax` para tokens de atualização (Refresh).

```rust
// CERTO: Retornando Refresh Token via Cookie Seguro no Axum
use axum::http::header::SET_COOKIE;

pub async fn login(
    State(state): State<AppState>,
    Json(payload): Json<LoginDto>,
) -> Result<impl IntoResponse, AppError> {
    let (user, access_token, refresh_token) = authenticate(&state.db, &payload).await?;

    // O browser gerencia este cookie para prevenir leitura via JavaScript
    let cookie = format!(
        "refresh_token={}; HttpOnly; Secure; SameSite=Lax; Path=/api/v1/auth/refresh; Max-Age=604800",
        refresh_token
    );

    Ok((
        axum::http::StatusCode::OK,
        [(SET_COOKIE, cookie)], // Cookie enviado diretamente via headers HTTP
        axum::Json(serde_json::json!({ 
            "access_token": access_token, // Token curto (15m) no body
            "user": user 
        }))
    ))
}

// ERRADO: Retornar o Refresh Token vulnerável no body do JSON
// Ok(Json(json!({ "access_token": token, "refresh_token": refresh_token })))
```

## 3. Padrão Frontend (React): Zustand + Axios Interceptor
O estado global (como Zustand) gerencia a reatividade UI do usuário logado, mas um _Axios Interceptor_ deve ser a verdadeira "malha de proteção" reativa aos erros HTTP 401 para renovação automática (silenciosa).

```typescript
// CERTO: Interceptor centralizado renovando JWT com cookie under-the-hood
import axios from 'axios';
import { useAuthStore } from '@/stores/auth';

export const api = axios.create({
  baseURL: '/api/v1',
  withCredentials: true, // OBRIGATÓRIO para o browser anexar o HttpOnly Cookie sozinho
});

api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;
    
    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true;
      try {
        // Post sem parâmetros! O cookie de refresh acompanha automaticamente
        const { data } = await axios.post('/api/v1/auth/refresh', {}, { withCredentials: true });
        
        useAuthStore.getState().setAccessToken(data.access_token);
        originalRequest.headers.Authorization = `Bearer ${data.access_token}`;
        
        // Refaz a request falha
        return api(originalRequest);
      } catch (refreshError) {
        // Se a renovação falhar, a sessão morreu.
        useAuthStore.getState().logout();
        window.location.href = '/login';
        return Promise.reject(refreshError);
      }
    }
    return Promise.reject(error);
  }
);

// ERRADO: Implementar logica de catch(401) solta dentro de cada component React que faz request Axios.
```

## 4. Autenticação e Extração no Rust (Axum Middleware)
Sempre extraia o Token Bearer via cabeçalho HTTP padrão, rejeite imediatamente acessos a rotas privadas. Utilize bibliotecas maduras como o `jsonwebtoken`.

```rust
// CERTO: O Axum isola o acesso e enriquece o Contexto da Requisição
use axum::extract::{Request, State};
use axum::middleware::Next;
use axum::response::Response;
use axum_extra::headers::{Authorization, authorization::Bearer};
use axum_extra::TypedHeader;

pub async fn require_auth(
    State(state): State<AppState>,
    TypedHeader(auth): TypedHeader<Authorization<Bearer>>,
    mut request: Request,
    next: Next,
) -> Result<Response, AppError> {
    let token = auth.token();
    
    let claims = verify_jwt(token, &state.config.jwt_secret)
        .map_err(|_| AppError::Unauthorized("Token inválido ou expirado".into()))?;
    
    // Injeta o tipo fortemente tipado `Claims` (User) para os Handlers 
    request.extensions_mut().insert(claims);
    
    Ok(next.run(request).await)
}
```

## 5. Gerenciamento de Mutações com Zod e RHF
No Frontend, **nunca confie que e-mails e senhas enviadas estão sanitizados**. Utilize React Hook Form associado a um Zod Schema Server-Side e Client-Side (`z.string().email()`, `z.string().min(8)`) para mitigar payload drops desnecessários e DDoS.

## 6. Gotcha: CSRF Auto-Retry Must Be Discriminated

Ao implementar retry automático de CSRF token em interceptors/middleware do frontend, NUNCA retente qualquer 403 automaticamente. Verifique o `error.code` da response:

```typescript
// ERRADO: retenta qualquer 403 → loop infinito em permission denial
if (res.status === 403) {
  await ensureCsrfToken();
  res = await doFetch(); // ← LOOP se a 403 é de permissão (ex: missing tenant)
}

// CERTO: só retenta se o erro é CSRF_INVALID
if (res.status === 403) {
  const cloned = res.clone();
  const body = await cloned.json().catch(() => ({}));
  if (body?.error?.code === "CSRF_INVALID") {
    await ensureCsrfToken();
    res = await doFetch(); // ← retry apenas para CSRF stale
  }
}
```

**Regra:** 403 pode significar CSRF inválido, permissão negada, tenant não encontrado, ou role insuficiente. Discriminar pelo `error.code` antes de retentar.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

