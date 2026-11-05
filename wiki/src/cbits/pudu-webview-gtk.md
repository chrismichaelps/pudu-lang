---
type: module
path: "@root/cbits/pudu_webview_gtk.c"
fidelity: Active
tags: [module, runtime, desktop, webview, linux]
aliases: [Pudu Webview GTK Adapter]
---

# Pudu Webview GTK Adapter

## Purpose and interface

Implements [[Pudu Webview Header]] on Linux with WebKitGTK 4.1 and GTK 3: windows with a fixed
container holding any number of views, the `pudu` URI scheme answered through request events,
navigation and new-window policy, user scripts and styles, content filters, inspector, zoom, user
agent, transparency, per-label website data, and script evaluation.

## Semantics

- The first call initializes GTK and records the calling thread; every later call from another
  thread answers `-2`.
- `pudu` is registered on each view's web context as a secure, CORS-enabled scheme. A request's
  method, headers and body are read when it starts; the response carries the program's status,
  headers and body.
- A data store label maps to `<user data dir>/<program>/webview/<sha256 of label>`, so no label can
  name a path outside the application's directory; `ephemeral` uses an ephemeral data manager.
- Fill views track the window's configured size; fixed views keep their frame.
- The pump iterates the default main context, blocking until a source fires or the slice's timeout
  elapses, and returns as soon as an event is queued; queuing wakes the context.
- Content rules are compiled into a filter store under the user cache directory; the initial page
  loads only after every filter is attached, and a filter that fails leaves the view empty, as on
  macOS.

## Grill Log

- **Q:** One web context per view? **A:** Yes: the scheme handler's user data must name its view,
  and isolation by label maps naturally onto a context with its own data manager.
- **Q:** Why is the build optional? **A:** Linking WebKitGTK makes every Linux build need its
  development headers, which server deployments of the compiler do not want; the `webkitgtk` cabal
  flag opts in, and without it Linux answers `unsupported`.

## Dependencies and consumers

Uses [[Pudu Webview Records]]. Called by [[Eval Webview]] when built with the `webkitgtk` flag.
Driven in CI by [[Webview GTK Harness]].

## Referenced by

[[src/cbits/_MOC]] · [[architecture/DESKTOP-WEBVIEW]]
