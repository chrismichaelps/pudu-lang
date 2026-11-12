---
type: module
path: "@root/cbits/pudu_webview_macos_window.m"
fidelity: Active
tags: [module, runtime, desktop, webview, macos]
aliases: [Pudu Webview macOS Window]
---

# Pudu Webview macOS Window

## Purpose and interface

Window chrome and state beyond opening and sizing: `minimize`, `unminimize`, `maximize`,
`unmaximize`, `toggle-maximize`, `always-on-top`, `decorations`, `closable`, `minimizable`,
`maximizable`, `resizable`, `background`, `titlebar`, `attention`, `badge`, `content-protected` and
`state`; `window-state`, `scale` and `theme` events; native drag regions; file drops onto views;
and `devtools-toggle`, `devtools-state`, `print` and `clear-data` for views.

## Semantics

- `window-state <id> <minimized> <maximized> <fullscreen> <visible> <focused>` is recorded whenever
  any of those changes, and on `state`.
- `titlebar visible|transparent|overlay`: `overlay` hides the title and lets content extend under
  the window buttons, for custom title bars.
- Drag regions: the bridge posts `drag` or `toggle-maximize` to the `puduWindow` message handler on
  a mouse-down over `data-pudu-drag-region`; the handler starts a drag only if the current event is a left-button press for that window and
  the button remains held. Delayed messages outside that event are ignored.
- File drops: a view configured with `file-drop` consumes dropped files instead of navigating to
  them and records `drop-enter`, `drop-over` and `drop <view> <x> <y> <paths>` or `drop-leave`.
- `devtools-toggle` opens or closes the inspector and records `devtools <view> open|closed`.
- `print` shows the print panel for the page; `clear-data` removes the view's website data.

## Grill Log

- **Q:** Why a native message handler for dragging when everything else goes through the `pudu`
  scheme? **A:** The native channel avoids the additional program pump, but delivery may still be
  delayed; the handler validates the current native press and ignores messages outside it.

## Dependencies and consumers

Uses [[Pudu Webview macOS Host]]; dispatched from [[Pudu Webview macOS Adapter]] and
[[Pudu Webview macOS View]].

## Referenced by

[[src/cbits/_MOC]] · [[architecture/DESKTOP-WEBVIEW]]

Resolved Grill Log: native drag and double-click actions require explicit per-view permissions
and an exact main-frame origin. The native channel grants no authority by default.
Inspector commands refuse views not configured for developer tools. Native extra commands validate
arity and flags before applying any side effect.

Resolved Grill Log: dragging requires the current event to be a left-button press in the same window with the button still held. A script message alone is insufficient. Drop paths use a JSON array field.

Resolved Grill Log: all inspector commands (open, close, toggle and state) are owned here, including developer-tools admission and explicit state events.

Resolved Grill Log: this unit also owns window-action parsing and interactive view construction (message delegate, view id and drop configuration). The view unit retains realization and navigation ownership.
