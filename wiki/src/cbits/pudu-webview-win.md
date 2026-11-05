---
type: module
path: "@root/cbits/pudu_webview_win.cpp"
fidelity: Active
tags: [module, runtime, desktop, webview, windows]
aliases: [Pudu Webview Windows Adapter]
---

# Pudu Webview Windows Adapter

## Purpose and interface

Implements [[Pudu Webview Header]] on Windows: Win32 windows, the message pump, the event queue,
request bodies and responses. Views come from [[Pudu Webview Windows View]]; shared declarations,
including the COM handler template, from [[Pudu Webview Windows Host]].

## Semantics

- The first call initializes COM for a single-threaded apartment and registers the window class;
  calls from another thread answer `-2`.
- The close button records `close-requested` and leaves the window open; resizing records `resized`
  and refits filling views; activation records `focused`.
- The pump dispatches messages until an event is queued or the slice ends, waiting in
  `MsgWaitForMultipleObjectsEx`; queuing posts a thread message that ends the wait.
- A response completes the request's deferral with a response built from the program's status,
  headers (line breaks converted to CRLF) and body.

## Grill Log

- **Q:** Link the WebView2 loader or load it? **A:** Load `WebView2Loader.dll` at run time. Its
  import library is built for one toolchain; loading it keeps the adapter linkable by any compiler and
  turns a missing loader into a typed `unsupported` refusal instead of a start-up failure.

## Dependencies and consumers

Uses [[Pudu Webview Records]]. Called by [[Eval Webview]] when built with the `webview2` flag; driven
in CI by [[Webview Drive Harness]].

## Referenced by

[[src/cbits/_MOC]] · [[architecture/DESKTOP-WEBVIEW]]
