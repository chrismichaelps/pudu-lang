---
type: module
path: "@root/cbits/pudu_webview_gtk_window.c"
fidelity: Active
aliases: [Pudu Webview GTK Window]
tags: [module, runtime, desktop, webview, linux]
---
# Pudu Webview GTK Window

## Purpose and interface

Window controls and native state: minimize/maximize, chrome flags, decorations, titlebar styles, background, attention and queries; window-state, scale, theme and placement reports.

## Semantics

Window-manager actions are asynchronous and state reflects observed native events. Signal handlers and explicit show/hide/focus report state. Geometry hints preserve both limits. Flags, dimensions and colors are checked before mutation. Native titlebars are constructed before realization; overlay controls sit above content. Desktop-wide badge and capture protection have no portable GTK guarantee and answer Unsupported explicitly.

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

Resolved Grill Log: reusable CSS providers replace prior background styling rather than accumulating on repeated updates; window titlebar providers are installed once.

Resolved Grill Log: the private fixed container reports zero preferred content size. Fill-view allocation must not become an implicit minimum that prevents later shrinking; explicit window geometry hints own minimum/maximum bounds. Native chrome retains its own minimum.

Resolved Grill Log: native titlebar buttons follow the same close/minimize/maximize hints as the window manager; resizing tests compare actual content size after both growth and shrink.

Resolved Grill Log: window size/placement events use GTK client dimensions, including an installed native menu bar. Fill views use the remaining fixed-container allocation. Remembering the smaller view allocation would shrink a window by the menu height on each restart.

Resolved Grill Log: overlay titlebar controls belong to the view container below any native menu bar; they must not cover the menu itself. Native geometry checks compare actual allocated menu, view and overlay positions.
