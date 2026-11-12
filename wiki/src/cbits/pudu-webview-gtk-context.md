---
type: module
path: "@root/cbits/pudu_webview_gtk_context.c"
fidelity: Active
aliases: [Pudu Webview GTK Context]
tags: [module, runtime, desktop, webview, linux, isolation]
---
# Pudu Webview GTK Context

## Purpose and interface

Own isolated website contexts and explicitly shared named stores. `pudu_view_context` returns one
owned context reference. The native process host retains one context per explicitly named persistent
store for the process lifetime; closing a view releases its WebView-owned reference. Unnamed and
ephemeral contexts are never cached.

## Semantics

Unnamed native views and views marked ephemeral get private ephemeral contexts. A persistent store
requires an explicit label; its existing SHA-256 directory layout is preserved. Views explicitly
naming the same persistent store reuse one context, avoiding simultaneous independent data managers
opening the same database. Scheme requests identify their originating view from the actual native
WebView, so shared storage never shares view IDs, invoke keys or command authority.

## Grill Log

- **Q:** Can an unnamed view use a process-wide default store? **A:** No. Sharing is explicit; a
  missing label gives an isolated ephemeral context.
- **Q:** Can a shared context's scheme handler capture its first view? **A:** No. Each request is
  routed from its native requesting WebView; closed views are refused before a pending record exists.
- **Q:** Who owns context lifetime? **A:** The process host owns named contexts. A closed view may
  leave clearing or network work in flight, so evicting the last visible view would allow a second
  manager to open the same database. The label cache preserves one manager across close/reopen;
  unnamed ephemeral contexts remain scoped to their native users.

## Dependencies and consumers

Uses [[Pudu Webview GTK Host]] and [[Pudu Webview GTK View]]. Consumed by
[[Pudu Webview GTK View]] and [[Pudu Webview GTK Interaction]].

## Referenced by

[[src/cbits/_MOC]] · [[architecture/DESKTOP-WEBVIEW]]
