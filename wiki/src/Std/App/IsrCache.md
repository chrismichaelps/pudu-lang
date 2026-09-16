---
type: module
path: "@root/lib/Std/App/IsrCache.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, application, cache, isr, tag-invalidation, zero-copy]
aliases: [Std App IsrCache]
---

# Std App IsrCache

## Purpose and interface

Thread-safe, zero-copy Incremental Static Regeneration (ISR) cache storing contiguous byte payloads (`Bytes`) with tag-based multi-route invalidation and stale-while-revalidate serving. Avoids string reallocations across thousands of concurrent requests by keeping rendered bytes ready for raw socket dispatch, and allows targeted cache purging when underlying database entities change.

Exports:
- `type CacheLookup = Fresh(Bytes, Str) | Stale(Bytes, Str) | Miss`: Result of looking up a cached response by key, carrying content bytes and ETag.
- `type IsrCache`: Thread-safe cache container protected by runtime mutex and cell synchronization.
- `create(capacity: Int) -> IsrCache`: Initializes a bounded cache with capacity limit.
- `get(cache: &IsrCache, key: Str, now: Int) -> CacheLookup`: Performs thread-safe lookup. Returns `Fresh` if `now < expiresAt`, `Stale` if `now < staleUntil`, or `Miss` otherwise.
- `put(cache: &IsrCache, key: Str, content: &Bytes, etag: Str, tags: &Array[Str], ttlSeconds: Int, staleSeconds: Int, now: Int) -> ()`: Stores or updates a cached entry with its associated tags, lifetime, and stale grace period.
- `revalidateTag(cache: &IsrCache, tag: Str, now: Int) -> Int`: Marks all entries bearing the specified tag as stale (expired), returning the count of tagged entries affected. Subsequent lookups for these entries will return `Stale`, allowing immediate serving while triggering background re-rendering.
- `purgeTag(cache: &IsrCache, tag: Str) -> Int`: Evicts all entries bearing the tag immediately from memory, returning the count of removed entries.
- `purgeKey(cache: &IsrCache, key: Str) -> Bool`: Evicts a single entry by key.
- `stats(cache: &IsrCache) -> (Int, Int, Int, Int)`: Returns `(currentSize, freshHits, staleHits, misses)`.

## Complexity and limits

Lookups and insertions operate in $O(N)$ linear scans over entries where $N \le \text{capacity}$. Capacities are bounded to prevent memory leakage. Storing pre-rendered `Bytes` avoids UTF-8 string conversions and GC pauses during high request concurrency.

## Grill Log

- **Q:** Why store `Bytes` directly instead of `Str`? **A:** Web responses are transmitted as raw octets over TCP sockets. Storing `Bytes` allows the server to send cached responses directly using vectorized socket writes without allocating new heap strings or invoking UTF-8 decoders/encoders on every cache hit.
- **Q:** What is the distinction between `revalidateTag` and `purgeTag`? **A:** `revalidateTag` marks entries as stale rather than evicting them. This implements Stale-While-Revalidate (SWR): incoming requests receive the cached content instantly without blocking on a slow database query, while the server re-renders in the background. `purgeTag` hard-deletes the entries immediately.
- **Q:** How does tag invalidation solve multi-page synchronization? **A:** When a user updates a blog post, calling `revalidateTag("post:123")` instantly updates the post page, the author's archive, and the recent posts widget without having to guess or enumerate all URL combinations.

## Dependencies and consumers

- [[Std Bytes]] supplies raw byte sequences.
- [[Std Sync]] supplies mutex and cell concurrency primitives.
- Consumed by SSR application routers, catalog pages, and API caching layers.

## Referenced by

[[src/Std/_MOC]] · [[2026-09-06-application-stack]]
