---
type: module
path: "@root/cbits/pudu_webview.h"
fidelity: Active
tags: [module, runtime, desktop, webview, abi]
aliases: [Pudu Webview Header]
---

# Pudu Webview Header

## Purpose and interface

The private, platform-neutral C ABI every WebView adapter implements: `pudu_webview_send`,
`pudu_webview_pump`, `pudu_webview_events`, `pudu_webview_body`, `pudu_webview_respond` and
`pudu_webview_failure`, with the status codes they share. Records and their fields are described in
[[architecture/DESKTOP-WEBVIEW]].

## Semantics

- Statuses: `0` done; `1` events are queued (pump only); `-1` invalid argument; `-2` not on the main
  thread; `-3` malformed record; `-4` platform failure; `-5` unknown window or view; `-6` request
  already finished or cancelled; `-7` unsupported on this platform.
- Byte-returning calls measure when given no buffer and copy only when the capacity fits, as the
  framebuffer adapter's input drain does.

## Grill Log

- **Q:** One entry point per feature, or a record channel? **A:** A record channel. Every feature
  added later is a record both sides already know how to frame, and a second platform adapter
  implements six functions instead of tracking a growing symbol list. _Rejected:_ per-feature
  functions, which multiply the evaluator's foreign imports and every adapter's surface.
- **Q:** Why does the program choose window and view ids? **A:** The program refers to a WebView in
  the same batch that creates it; ids assigned by the adapter would force a round trip per creation.

## Dependencies and consumers

Implemented by [[Pudu Webview macOS Adapter]] and [[Pudu Webview GTK Adapter]]; called by
[[Eval Webview]].

## Referenced by

[[src/cbits/_MOC]] · [[architecture/DESKTOP-WEBVIEW]]
