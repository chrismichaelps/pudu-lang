---
type: module
path: "@root/cbits/pudu_webview_macos.m"
fidelity: Active
tags: [module, runtime, desktop, webview, macos]
aliases: [Pudu Webview macOS Adapter]
---

# Pudu Webview macOS Adapter

## Purpose and interface

Implements [[Pudu Webview Header]] on macOS: starts the application with a standard menu bar (so
copy, paste, undo and quit reach a WebView), dispatches command records to windows and views, pumps
the loop, queues events, and finishes pending `pudu://` requests.

## Semantics

- Every entry point refuses off the main thread with `-2`.
- `send` stops at the first failing record; the failure text names the record's verb and target.
- `pump` returns `1` as soon as an event is queued: queuing posts an application-defined wake event
  that ends the wait, and that event is consumed rather than dispatched.
- A window's close button records `close-requested` and leaves the window open; the program closes
  it, so destruction stays ordered.
- `respond` to a request that WebKit already stopped answers `-6` and nothing is sent.
- Request bodies are read from the request's body or, when WebKit provides a stream instead, by
  draining the stream once when the request starts.

## Grill Log

- **Q:** Why install a menu bar the program did not ask for? **A:** Editing shortcuts reach a WebView
  only through the menu's standard actions; without them Cmd-C does nothing in a text field. The
  application menu offers only Quit, which records `close-requested` for every window.
- **Q:** Why is a stopped request kept as `-6` rather than ignored silently? **A:** The program can
  then tell a cancelled call from a delivered one in tests; the evaluator maps it to a typed
  `RequestGone`.

## Dependencies and consumers

Uses [[Pudu Webview Records]] and [[Pudu Webview macOS Host]]; views come from
[[Pudu Webview macOS View]]. Called by [[Eval Webview]]. Live behavior is covered by
[[Desktop Webview Gate]].

## Referenced by

[[src/cbits/_MOC]] · [[architecture/DESKTOP-WEBVIEW]]
