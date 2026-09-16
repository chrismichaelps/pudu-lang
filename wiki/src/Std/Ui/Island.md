---
type: module
path: "@root/lib/Std/Ui/Island.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, ui, island, hydration, progressive-enhancement]
aliases: [Std Ui Island]
---

# Std Ui Island

## Purpose and interface

Islands architecture and progressive enhancement for server-rendered applications. Emits isolated `<pudu-island>` container boundaries with initial server-rendered HTML, paired with an ultra-lightweight client micro-runtime (< 1.5 KB), scoped lifecycle management, deferred hydration strategies, and native form degradation.

Exports:
- `type Hydration = Eager | Visible | Idle`: Hydration scheduling modes.
- `island(name: Str, propsJson: Str, fallback: Html.Html) -> Html.Html`: Wraps a server-rendered component in a `<pudu-island data-name="..." data-props="..." data-hydrate="eager">` custom element.
- `islandWithHydration(name: Str, propsJson: Str, fallback: Html.Html, hydration: Hydration) -> Html.Html`: Wraps a server-rendered component with an explicit hydration scheduling strategy (`eager`, `visible`, or `idle`).
- `serverActionForm(actionUrl: Str, csrfToken: Str, fields: &Array[Html.Html]) -> Html.Html`: Builds an accessible HTML form with hidden CSRF tokens that submits natively via standard HTTP POST.
- `microRuntime(nonce: Str) -> Html.Html`: Generates the self-contained micro-runtime script authorized by the given CSP nonce.

### Client Micro-Runtime (`window.PuduIslands`)

The micro-runtime registers the custom element `<pudu-island>` with:
- **Hydration Scheduling:**
  - `eager`: Mounts immediately once registered and connected to DOM.
  - `visible`: Defers mounting using an `IntersectionObserver` until the island scrolls into viewport.
  - `idle`: Defers mounting using `requestIdleCallback` (with 2s timeout and `setTimeout` fallback).
- **Lifecycle & Cleanup:**
  - Provides each island mount function with `(element, props, signal)` where `signal` is an `AbortSignal`.
  - Mount functions may return a synchronous or asynchronous cleanup function.
  - When disconnected, pending operations are cancelled via `AbortController.abort()`, scheduled callbacks are cleared, and the cleanup function is invoked.
  - Generational tokens protect against race conditions when islands are rapidly removed and reinserted into DOM.
  - Dispatches `pudu:island-ready` on successful mount and `pudu:island-error` on parse or mount failures.
- **Registration APIs:**
  - `PuduIslands.register(name, mount)`: Registers a synchronous or asynchronous component mount handler.
  - `PuduIslands.registerLazy(name, load)`: Registers an on-demand module loader (`() => import(...)`), loading the JS bundle only when the island is actually scheduled for mounting.

## Complexity and limits

$O(1)$ memory per island marker. The client micro-runtime is strictly bounded to $< 1.5$ KB uncompressed and zero external dependencies. Complies with [[architecture/WEB]]: there is no dual-pass virtual DOM hydration and hydration mismatch is unrepresentable.

## Grill Log

- **Q:** How do islands avoid hydration mismatches? **A:** The server renders the authoritative initial markup. The client micro-runtime does not re-render or walk virtual DOM trees; it attaches event listeners directly to existing DOM nodes.
- **Q:** Does the application fail when JavaScript is disabled? **A:** No; server action forms submit via native browser HTTP POST and redirect via standard 303 See Other responses.
- **Q:** What is the payload cost of the micro-runtime? **A:** Less than 1.5 KB of vanilla JS, inlined once per page with the request's CSP nonce.
- **Q:** Why support `Visible` and `Idle` hydration? **A:** Heavy interactive components below the fold (e.g. comments, analytics, charts) should not block the main thread or delay First Contentful Paint. Deferring until visible via `IntersectionObserver` or idle via `requestIdleCallback` keeps the page fast and responsive.
- **Q:** Why provide `AbortSignal` and cleanup callbacks? **A:** Single-page navigation or DOM replacement (e.g., swapping pages via Turbo or dynamic updates) removes islands. Providing scoped abort signals and unmount cleanups prevents memory leaks, dangling listeners, and orphaned timers.
- **Q:** Why include `registerLazy`? **A:** It allows code-splitting island implementations into separate ES modules that are downloaded only when their containing island becomes visible or idle on the client.

## Dependencies and consumers

- [[Std Html]] supplies element construction.
- Consumed by interactive SSR views and forms.

## Referenced by

[[src/Std/_MOC]] · [[2026-09-06-application-stack]]

