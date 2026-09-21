---
type: module
path: "@root/lib/Std/Html/Stream.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, html, streaming, suspense, early-flush]
aliases: [Std Html Stream]
---

# Std Html Stream

## Purpose and interface

Streaming HTML generator for progressive document delivery and out-of-order Suspense boundary resolution. Enables early flush of critical document metadata, assets, and skeletons, followed by asynchronous content replacement using self-contained inline DOM script insertion without client-side library runtimes.

Exports:
- `documentHead(title: Str, meta: &Array[(Str, Str)], criticalCss: Str, preloads: &Array[Str]) -> Bytes`: Renders complete `<!DOCTYPE html><html lang="en"><head>...` block formatted for immediate socket dispatch.
- `documentTail() -> Bytes`: Renders closing `</body></html>` markup.
- `suspensePlaceholder(boundaryId: Str, fallback: &Bytes) -> Bytes`: Generates `<div id="pudu-s-{id}">{fallback}</div>` boundary container.
- `suspenseReplacement(boundaryId: Str, content: &Bytes) -> Bytes`: Generates `<template id="pudu-t-{id}">{content}</template>` and an inline replacement snippet that swaps placeholder contents as soon as the chunk arrives over the network stream.
- `suspenseError(boundaryId: Str, errorFallback: &Bytes) -> Bytes`: Generates an out-of-order error fallback chunk that replaces the pending suspense placeholder and tags it with `data-pudu-error="true"`, preventing stream failure.
- `renderSuspended(boundaryId: Str, fallback: &Bytes, content: &Bytes) -> (Bytes, Bytes)`: Produces paired initial placeholder chunk and deferred resolution chunk.
- `TrustedCss` and `trustedCss`: Explicitly mark stylesheet source the caller has reviewed; raw CSS
  cannot be supplied as ordinary text to the safe head path.
- `PreparedHead`, `prepareHead`, and `headBytes`: Prepare reusable early-head bytes from escaped
  title/metadata text, typed `Html.Destination` preloads, and explicit trusted CSS.
- `BoundaryError = { boundaryId: Str }`: Refusal carrying an empty or non-ASCII-alphanumeric ID.
- `placeholder`, `replacement`, `errorReplacement`, and `suspended`: Safe suspense helpers accepting
  typed `Html` fallback/content and returning `Result`; ordinary text therefore renders as text and
  trusted markup remains explicit.
- `Deferred`, `defer`, `deferredInitial`, and `resolveDeferred`: Retain a validated typed fallback
  as immediately available bytes and a fallible body producer that is not invoked until resolution
  is explicitly requested.

The original string/byte helpers remain unchecked compatibility entry points. New code migrates to
the prepared-head and typed suspense APIs; intentional raw markup remains visible through
`Html.trusted`, and intentional raw CSS through `trustedCss`.

## Complexity and limits

Safe markup generation delegates text, attribute escaping, handler blocking, trusted markup, and
non-recursive traversal to [[Std Html]]. Inline replacement uses vanilla DOM manipulation
(`replaceChildren` / `content.cloneNode`) directly in the browser's streaming parser. No client
virtual DOM or hydration runtime is loaded. Boundary IDs must be unique, non-empty ASCII
alphanumerics within a document. No allocation or complexity improvement is claimed by the safety
migration.

## Grill Log

- **Q:** How does out-of-order rendering work without client frameworks? **A:** The server emits an initial fallback placeholder into the main document body. When the deferred asynchronous data completes, the server writes a hidden `<template>` plus an inline `<script>` chunk that moves template children into the placeholder target immediately.
- **Q:** What if JavaScript is disabled in the browser? **A:** The browser displays the server-rendered fallback skeleton; core page links and standard form navigation remain fully functional.
- **Q:** Does early flush guarantee lower TTFB? **A:** No; the module only prepares bytes that a
  caller may flush. Delivery timing and performance require measurement in the consuming server.
- **Q:** Escape arbitrary CSS as text? **A:** No; CSS has its own grammar and `</style>` boundary.
  Safe head preparation requires visibly explicit `TrustedCss` rather than claiming HTML escaping
  makes stylesheet source safe.
- **Q:** HTML-escape an identifier before placing it in JavaScript? **A:** No; HTML and JavaScript
  are different contexts. Safe suspense helpers accept only non-empty ASCII alphanumerics, which
  require no context-specific quoting.
- **Q:** Accept rendered bytes as safe fallback/content? **A:** No; safe helpers accept `Html` so
  text stays text, while trusted markup requires `Html.trusted`. Legacy byte helpers remain named
  compatibility paths.
- **Q:** Rebuild the same safe head for every request? **A:** No; `prepareHead` retains immutable
  bytes in `PreparedHead`, and `headBytes` returns them for reuse.
- **Q:** Ask for deferred content merely to obtain its placeholder? **A:** No; `defer` renders and
  retains only the typed fallback. `deferredInitial` cannot invoke the producer; `resolveDeferred`
  is the explicit late boundary and preserves a producer failure as `Result`.

## Dependencies and consumers

- [[Std Bytes]] supplies raw byte sequences.
- [[Std Html Buffer]] supplies low-level byte layout.
- Consumed by enterprise SSR pages and streaming HTTP handlers.

## Referenced by

[[src/Std/_MOC]] · [[2026-09-06-application-stack]] ·
[[2026-09-21-safe-html-streaming]] · [[2026-09-21-incremental-html-output]]
