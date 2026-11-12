---
type: module
path: "@root/test/native/WebviewOwnership.cpp"
fidelity: Active
aliases: [Webview Windows Ownership Harness]
tags: [module, test, desktop, windows, ownership]
---
# Webview Windows Ownership Harness

## Purpose and interface

Exercise native reference ownership of views and pending requests with counted doubles from
[[Webview Windows Doubles]]. Requests enter through the production resource callback; answers go
through `pudu_webview_respond`; teardown through view and window close records.

## Cases

| Case | Expected |
| --- | --- |
| Deferral acquisition fails, or returns null | synchronous 503, no `request` event, all references returned |
| Respond to a live request | response built by that request's own environment; deferral completed once |
| Respond when the response cannot be built | still completed and released once; Gone |
| Close a view with pending requests | each completed and released once before controller Close; later respond is Gone |
| Close one of two views | the other view's pending request still answers with its own environment |
| Close, then recreate the same id | the new view's request is unaffected by the old close |
| Deferral completion reenters respond | Gone; nothing released twice |
| Owned environment, controller and renderer | released exactly once by close; window close releases its views |

## Grill Log

- **Q:** Why counted doubles? **A:** Exactly-once release is a count. The doubles report
  completions and references directly, which no renderer exposes.
- **Q:** Why include reentrant completion? **A:** Native completion may dispatch synchronously.
  Detaching a record before finishing it is what makes reentry harmless; the case proves the order.

## Dependencies and consumers

Uses [[Pudu Webview Windows Host]], [[Pudu Webview Windows Adapter]], [[Pudu Webview Windows Request]] and [[Webview Windows Doubles]]. Run by [[Desktop Webview CI]].

## Referenced by

[[src/_MOC]] · [[Pudu Webview Windows Adapter]] · [[Desktop Webview CI]]
