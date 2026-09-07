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
- `renderSuspended(boundaryId: Str, fallback: &Bytes, content: &Bytes) -> (Bytes, Bytes)`: Produces paired initial placeholder chunk and deferred resolution chunk.

## Complexity and limits

Markup generation executes in $O(M)$ where $M$ is fragment byte length. Inline replacement uses vanilla DOM manipulation (`replaceWith` / `content.cloneNode`) executing directly in the browser's streaming HTML parser. No client virtual DOM or hydration runtime is loaded. Boundaries must have unique alphanumeric IDs within a document.

## Grill Log

- **Q:** How does out-of-order rendering work without client frameworks? **A:** The server emits an initial fallback placeholder into the main document body. When the deferred asynchronous data completes, the server writes a hidden `<template>` plus an inline `<script>` chunk that moves template children into the placeholder target immediately.
- **Q:** What if JavaScript is disabled in the browser? **A:** The browser displays the server-rendered fallback skeleton; core page links and standard form navigation remain fully functional.
- **Q:** Does early flush increase TTFB? **A:** No; early flush drastically *reduces* initial TTFB and Time to First Contentful Paint by transmitting the `<head>` and critical styles while backend database queries execute concurrently.

## Dependencies and consumers

- [[Std Bytes]] supplies raw byte sequences.
- [[Std Html Buffer]] supplies low-level byte layout.
- Consumed by enterprise SSR pages and streaming HTTP handlers.

## Referenced by

[[src/Std/_MOC]] · [[2026-09-06-application-stack]]
