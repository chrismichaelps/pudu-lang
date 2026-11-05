---
type: handoff
status: ACTIVE
issue: 833
aliases: [Pudu Desktop Delivery]
tags: [handoff, desktop, webview, ipc, packaging, updates]
---
# Pudu Desktop Delivery

Issue #833 on `feature/833-pudu-desktop` from dev. Roles: Language Architect resolved
[[architecture/DESKTOP-WEBVIEW]] and [[decisions/ADR-0026-a-webview-is-a-renderer]] before source;
Runtime Engineer owns the adapters and [[Eval Webview]]; Standard Library Engineer owns
`Std.Desktop.*` and [[Std Crypto Sign]]; Tooling/Release owns [[Std Desktop Cli]], packaging, the
gate and CI. Independent implementation, Language Architect and Forensic Guardian reviews are
pending; no self-approval.

## Delivered

- macOS WebKit adapter and WebKitGTK adapter (behind `webkitgtk`) for one six-entry record channel.
- `Std.Desktop`: views, protocol, typed IPC with streams and events, generated TypeScript,
  capabilities, plugins, the run loop with development reload, signed and patched updates with
  rollback, packaging for `.app`, `.dmg`, `.deb`, `.rpm`, AppImage, NSIS and MSI, and `pudu desktop`.
- Runtime: Ed25519, `modifiedTime`, `executablePath`, and sidecar programs for signable packages.

## Validation evidence

- [[Desktop Webview Gate]] passes locally, including a live WebView self-test (9/9) on macOS.
- The packaged, signed `Notes.app` launched from `/` without a library path passes the same self-test.
- `dpkg-deb` and `rpm -K` accept the written packages (header and payload digests OK).
- [[Webview Drive Harness]] passes against the macOS adapter: scheme requests, injected scripts,
  evaluation, navigation refusal, content-rule blocking, and two views in one window.

## Open

- Hybrid UI components (menu bar, dialogs, native surfaces) exist on macOS; WebKitGTK and WebView2
  refuse them as `unsupported`. Dialog answers were not exercised automatically, since a person
  must choose.

- Windows: the WebView2 adapter is verified by the native harness in CI; a compiler built on Windows
  with the `webview2` flag has not been exercised, because CI builds the compiler on Linux only.
- Language bugs found and filed: pudu-lang#834 (generic closure loses a forwarded type argument),
  pudu-lang#835 (a derive cannot see a hand-written implementation from another module),
  pudu-lang#836 (trait implementations for unit are unreachable). The framework avoids each.

## Exact next action

Confirm [[Desktop Webview CI]] drives all three adapters green on the pull request, then obtain the
independent reviews.

## Referenced by

[[handoffs/_MOC]] · [[architecture/DESKTOP-WEBVIEW]]
