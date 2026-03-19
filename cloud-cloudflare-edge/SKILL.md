---
name: Cloudflare Edge (Workers, R2, D1)
description: Architect, generate, and validate edge-first serverless applications using Cloudflare Workers, R2 (Object Storage), D1 (SQL Database), and Cache API. Enforces zero cold starts, CDN optimization, and global distribution patterns.
---

# Cloudflare Edge (Workers, R2, D1)

A arquitetura *Edge-First* inverte o modelo tradicional: a computação deixa de residir em um datacenter central (ex: US-East-1) e passa a rodar na ponta (Point of Presence - PoP), a menos de 50ms do usuário global, garantindo latências insanas e "Zero Cold Starts".

## 🏛️ Dogmas de Arquitetura Cloudflare Edge

1. **ABRACE OS ISOLATES (0ms Cold Start):** Diferente da AWS Lambda que roda Containers por baixo (podendo causar Cold Starts de 500ms+), Cloudflare Workers usam V8 Isolates. Não dependa de runtimes massivos em Node.js. OBRIGATÓRIO garantir bundle size minimalista. Evite ao máximo dependências pesadas baseadas puramente em APIs Node (FileSystem `fs`, `child_process`).
2. **R2 PARA STORAGE SEM EGRESS:** A AWS S3 pune startups com taxas de "Egress Data" (banda de saída de download). O Cloudflare R2 possui *Zero Egress Fees*. OBRIGATÓRIO usar o R2 para hospedar imagens, vídeos e assets em massa se o produto servir petabytes para o mundo público, acoplado rigidamente ao CDN customizado por um Worker.
3. **D1 COMO BANCO EDGE, COM CACHE:** O Cloudflare D1 é um serverless SQLite replicado globalmente de forma inteligente. Porém, acessos pesados sequenciais ainda sofrem latência transcontinental dependendo da rede subjacente. OBRIGATÓRIO cachear Leituras Quentes usando o `Cache API` (Tiered Cache) nativo ou Workers KV na frente do banco D1.
4. **CACHE API PROGRAMÁTICO (Fetch Event):** Nunca confie apenas nas Page Rules estáticas de painel. OBRIGATÓRIO utilizar programação interceptiva de Cache (`request -> process -> respond | cache`) no Worker para forçar "Stale-While-Revalidate", segmentação granular via Headers customizados (Bypass em Logged Users) e TTL flexíveis para URLs complexas.
5. **NÃO BLOQUEIE O EVENT LOOP:** Como milhares de requests compartilham a thread num Isolate, algoritmos intensivos de CPU (Criptografia RSA manual long, Image Transcoding bloqueante sem Streams) matarão o Worker (Timeout CPU `10-50ms` do CF). Delegue esses processamentos ou use WebAssembly (Wasm).

## 🛑 Padrões (Certo vs Errado)

### Padrão de Caching CDN Programático via Cache API

**❌ ERRADO** (Buscar no banco de dados todas as vezes no Edge, causando lentidão ao D1 Global):
```typescript
// bad-worker.ts
export default {
  async fetch(request, env) {
    const data = await env.DB.prepare("SELECT * FROM heavy_posts").all();
    return new Response(JSON.stringify(data), { headers: { "Content-Type": "application/json" }});
  }
}
```

**✅ CERTO** (Stale-While-Revalidate com Cache API Local do Datacenter CF):
```typescript
// good-worker.ts
export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const cache = caches.default;
    let response = await cache.match(request); // Checa o CDN local!

    if (!response) {
      // Cache MISS: Pega no D1
      const data = await env.DB.prepare("SELECT * FROM heavy_posts LIMIT 50").all();
      response = new Response(JSON.stringify(data), { 
        headers: { 
            "Content-Type": "application/json",
            "Cache-Control": "s-maxage=60, stale-while-revalidate=300" // Cache por 1 min
        }
      });
      // Salva no Cache em background sem bloquear a resposta ao usuário
      ctx.waitUntil(cache.put(request, response.clone())); 
    }
    return response;
  }
}
```

### Consumindo R2 via Binding Seguro (Sem chaves expostas publicas)

**❌ ERRADO** (Tratar o R2 igual S3 antigo puxando credenciais e expondo Public Bucket pra tudo):
```typescript
// Fornecer a URL pública crua de R2 sem proteção para o frontend
return new Response(`https://pub-21390xdada.r2.dev/minha-imagem-secreta.jpg`);
```

**✅ CERTO** (Download Seguro / Streaming interno mascarado através do Worker):
```typescript
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const key = url.pathname.slice(1); // Ex: /imagens/id_123.jpg
    
    // Busca direto do R2 Bucket Binding (Injetado via wrangler.toml `r2_buckets`)
    const object = await env.MY_BUCKET.get(key); 
    
    if (object === null) return new Response("Object Not Found", { status: 404 });
    
    const headers = new Headers();
    object.writeHttpMetadata(headers);
    headers.set('etag', object.httpEtag);
    
    // Retorna a stream pura mascarada via domínio da API (Sem Expor o Cloudflare R2 publicamente)
    return new Response(object.body, { headers }); 
  }
}
```
