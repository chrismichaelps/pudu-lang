---
type: module
path: "@root/cbits/pudu_webview_gtk_interaction.c"
fidelity: Active
aliases: [Pudu Webview GTK Interaction]
tags: [module, runtime, desktop, webview, linux]
---
# Pudu Webview GTK Interaction

## Purpose and interface

Authenticated native drag regions, opt-in file drops, inspector controls, page printing and website data clearing.

## Semantics

The application sends window-authority records containing action, exact origin and a fresh bridge key. The authorized native message channel accepts JSON carrying that key and the matching current top-level origin. Unlike ordinary scheme calls, native script callbacks lack trustworthy frame metadata; the key remains in the top-frame bridge closure. A drag also requires a retained physical press for this view and a still-held button. Dropped paths are encoded losslessly as a JSON array. Inspector access is refused when disabled; programmatic actions report state. No grant is enabled by default.

## Grill Log

- **Q:** Which layer owns authority and native state? **A:** The Pudu application grants operations;
  this boundary validates and translates them. Native handles, callbacks and memory stay private.
- **Q:** Can an unavailable desktop feature report success? **A:** No. Unsupported operations return
  the shared typed status, and malformed records are refused before any mutation.

## Dependencies and consumers

Uses [[Pudu Webview Records]] and [[Pudu Webview GTK Host]]. Consumed by
[[Pudu Webview GTK Adapter]], [[Pudu Webview GTK View]] and [[Webview Drive Harness]].

## Referenced by

[[src/cbits/_MOC]] · [[architecture/DESKTOP-WEBVIEW]]

Resolved Grill Log: clearing reports the shared two-field success event or an explicitly decoded three-field failure event.

Resolved Grill Log: inspector open/closed signals own observed state; a separate requested state orders rapid toggles while platform transitions complete. Invalid drop selections are refused as a whole, and their native signal is consumed so WebKit cannot navigate to the dropped URI.

Resolved Grill Log: closing a view destroys its widget, while the process-owned named context remains valid for pending clearing or network operations.
