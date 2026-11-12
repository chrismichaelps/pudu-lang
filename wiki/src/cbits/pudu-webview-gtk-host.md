---
type: module
path: "@root/cbits/pudu_webview_gtk.h"
fidelity: Active
aliases: [Pudu Webview GTK Host]
tags: [module, runtime, desktop, webview, linux]
---
# Pudu Webview GTK Host

## Purpose and interface

Private shared window, view and pending-request state. Window state includes geometry limits and control hints; view interaction state retains per-action origin grants, a bridge key and the last physical button press. Helpers remain private to the adapter, with no additional public ABI entry point.

## Semantics

Shared structs are the contract between the GTK adapter, view, window controls, interaction and native component units. Keep asynchronous GTK callbacks on the adapter main thread; validate record arity before indexing fields.

## Grill Log

- **Q:** Which layer owns authority and native state? **A:** The Pudu application grants operations;
  this boundary validates and translates them. Native handles, callbacks and memory stay private.
- **Q:** Can an unavailable desktop feature report success? **A:** No. Unsupported operations return
  the shared typed status, and malformed records are refused before any mutation.

## Dependencies and consumers

Declares the private SDK types and helpers over [[Pudu Webview Records]]. Consumed by
[[Pudu Webview GTK Adapter]], [[Pudu Webview GTK View]], [[Pudu Webview GTK Context]],
[[Pudu Webview GTK Window]], [[Pudu Webview GTK Interaction]] and [[Webview Drive Harness]].

## Referenced by

[[src/cbits/_MOC]] · [[architecture/DESKTOP-WEBVIEW]]

Resolved Grill Log: the process host retains named contexts across view closure; unnamed and ephemeral contexts do not enter the shared-store table.

Resolved Grill Log: the private thread guard returns a shared status to both adapter and view units.
