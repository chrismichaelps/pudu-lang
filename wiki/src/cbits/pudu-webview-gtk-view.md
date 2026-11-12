---
type: module
path: "@root/cbits/pudu_webview_gtk_view.c"
fidelity: Active
aliases: [Pudu Webview GTK View]
tags: [module, runtime, desktop, webview, linux]
---
# Pudu Webview GTK View

## Purpose and interface

Collect view configuration, realize isolated WebKit contexts, serve pending scheme requests, apply navigation policy, scripts/rules and evaluation, and dispatch inspection/interaction commands.

## Semantics

Configuration precedes realization. Window interaction authority is collected before scripts run. Inspector operations require devtools permission; file drops are opt-in and transport paths as a JSON array. Unsupported platform operations return typed failure rather than success.

- The scheme handler collects method, headers and body into a pending record and copies the
  requesting view ID from the native WebView. `respond` validates thread and status before finishing
  that request with its supplied response bytes and headers.
- Navigation admits the local scheme and configured patterns; new-window requests are refused.
- Scripts, styles, store, rules and interaction authority are configured before realization.
  Rule compilation completes before the initial page loads; a failed rule leaves the page empty.
- Evaluation reports the ticket, success/failure and a string or JSON value through the shared
  event channel. Inspector and interaction commands dispatch to their dedicated unit.

## Grill Log

- **Q:** Which layer owns authority and native state? **A:** The Pudu application grants operations;
  this boundary validates and translates them. Native handles, callbacks and memory stay private.
- **Q:** Can an unavailable desktop feature report success? **A:** No. Unsupported operations return
  the shared typed status, and malformed records are refused before any mutation.

## Dependencies and consumers

Uses [[Pudu Webview Records]], [[Pudu Webview GTK Host]], [[Pudu Webview GTK Context]] and
[[Pudu Webview GTK Interaction]]. Consumed by [[Pudu Webview GTK Adapter]] and
[[Webview Drive Harness]].

## Referenced by

[[src/cbits/_MOC]] · [[architecture/DESKTOP-WEBVIEW]]

Resolved Grill Log: closing a view clears its native key, press and action grants before destroying the widget, so delayed native messages cannot access a released widget.

Resolved Grill Log: request routing reads the requesting native view rather than capturing a context owner. Context creation/sharing lives in the context unit, and the process host retains named stores across view closure.

Resolved Grill Log: respond checks thread ownership before reading or completing pending requests.

Resolved Grill Log: zero-length headers use an empty string for GLib parsing; positive NULL header/body slices are refused before reading pending state.
