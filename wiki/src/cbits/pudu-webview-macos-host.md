---
type: module
path: "@root/cbits/pudu_webview_macos.h"
fidelity: Active
tags: [module, runtime, desktop, webview, macos]
aliases: [Pudu Webview macOS Host]
---

# Pudu Webview macOS Host

## Purpose and interface

The private Objective-C interfaces the macOS adapter's translation units share: `PuduWebHost`
(the process-wide registry of windows, views, pending requests, the event queue and the last
failure), `PuduWebWindow` (one window and its flipped content view), and `PuduWebView` (one WebView,
its collected configuration, and its delegates). No type here crosses into Pudu.

## Grill Log

- **Q:** One host per window or per process? **A:** Per process. The platform loop, the menu bar,
  the URL scheme's pending requests and the event queue are process-wide; ids from the program keep
  windows and views apart.

## Dependencies and consumers

Shared by [[Pudu Webview macOS Adapter]] and [[Pudu Webview macOS View]].

## Referenced by

[[src/cbits/_MOC]]
