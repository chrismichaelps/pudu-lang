---
type: module
path: "@root/cbits/pudu_webview_gtk_native.c"
fidelity: Active
tags: [module, runtime, desktop, webview, linux, hybrid]
aliases: [Pudu Webview GTK Native]
---

# Pudu Webview GTK Native

## Purpose and interface

The `app menu`, `app dialog` and `surface` records of [[Pudu Webview macOS Native]] on WebKitGTK:
a `GtkMenuBar` above each window's views with accelerators, native file choosers and message
dialogs, and a drawing area presenting Canvas frames.

## Semantics

- The menu bar is built for every open window and remembered for windows opened later; chords map
  `cmd` and `ctrl` to the primary modifier. A malformed line refuses the whole bar.
- File choosers and message dialogs are non-blocking and answer with `dialog-ok` or `dialog-cancel`;
  closing a message dialog without choosing is a cancel.
- A surface scales its frame to its size without smoothing and reports presses in frame pixels.

## Grill Log

- **Q:** Why the portal-aware file chooser rather than the GTK dialog widget? **A:** It uses the
  desktop's own chooser where one exists, including inside sandboxes, and falls back to the widget.

## Dependencies and consumers

Uses [[Pudu Webview Records]]; dispatched from [[Pudu Webview GTK Adapter]].

## Referenced by

[[src/cbits/_MOC]]
