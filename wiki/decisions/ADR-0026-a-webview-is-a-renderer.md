---
type: decision
status: ACCEPTED
date: 2026-11-05
tags: [decision, desktop, webview, security]
aliases: [ADR-0026-a-webview-is-a-renderer, ADR-0026 A WebView Is a Renderer]
---

# ADR-0026: A WebView Is a Renderer

## Context

Desktop applications whose interface is HTML need a WebView, an IPC channel, a security model,
packaging and updates. The common shape makes the page the center: it holds an ambient API object,
calls into the host with string-keyed messages, and is trusted because it was bundled. Each of those
choices leaks authority into the least-checked part of the program.

## Decision

1. **The Pudu program owns the application.** Windows, WebViews, assets, IPC answers, navigation
   decisions and updates are Pudu values and Pudu calls. The page holds only the bridge it was given.
2. **One record channel crosses the native boundary** ([[architecture/DESKTOP-WEBVIEW]]): six C entry
   points and length-prefixed records, instead of an entry point per feature. A new WebView feature
   is a new record, not a new ABI symbol, and each platform adapter is one implementation of one
   contract.
3. **The program serves the origin.** `pudu://app/` and `pudu://ipc/` are answered by the program,
   so assets, headers and calls pass the same checks, and binary bodies cross without encoding.
4. **Types are the contract.** A command's argument and result types produce both its decoder and
   its TypeScript declaration, so the two sides cannot drift.
5. **Deny by default.** No command is callable until a capability grants it to a WebView and origin;
   any deny wins; plugins declare permissions and are refused whole without them.
6. **Updates are always verified.** Ed25519 signatures over every artifact, with no switch to turn
   verification off; a patch must rebuild the exact full artifact; an unconfirmed install rolls back.
7. **Tools a format needs are named, not assumed.** Formats written natively (`.app`, `.deb`, `.rpm`,
   AppDir, NSIS and WiX sources) need nothing installed; image and installer compilers are invoked
   and a missing one is a typed failure.

## Consequences

- Latency of an IPC call is one pump turn; the adapter wakes the loop when it queues an event.
- Synchronous navigation decisions cannot ask the program, so navigation policy is configuration the
  adapter enforces, with every refusal reported as an event.
- A long-running command blocks the loop that runs it; long work runs on a `Std.Concurrent` worker
  and reports through a channel.
- Windows support needs a WebView2 adapter for the same six entry points; until then the target
  answers `UnsupportedPlatform`.

## Referenced by

[[decisions/_MOC]] · [[architecture/DESKTOP-WEBVIEW]]
