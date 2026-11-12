---
type: module
path: "@root/cbits/pudu_webview_macos_native.m"
fidelity: Active
tags: [module, runtime, desktop, webview, macos, hybrid]
aliases: [Pudu Webview macOS Native]
---

# Pudu Webview macOS Native

## Purpose and interface

Native components that share a window with WebViews: `app menu` installs the application's menu
bar, `app dialog` shows open, save and message dialogs, and `surface` records place, present and
remove a native pixel surface inside a window. Choosing a menu command, answering a dialog and
pressing a surface are reported as events.

## Semantics

- `app menu <lines>`: tab-separated lines `menu depth title`, `item depth name chord title`,
  `separator depth`. Items run in order; an item records `menu <name>`. The application menu with
  Quit stays first; the Edit menu is kept unless the program supplies its own.
- `app dialog <ticket> open <title> <multiple> <directories>` and `... save <title> <name>` run as
  non-blocking panels and record `dialog-ok <ticket> <paths, one per line>` or `dialog-cancel <ticket>`.
  `... message <style> <title> <text> <buttons>` records `dialog-ok <ticket> <index>` for the button
  chosen; buttons are comma separated, the first is the default.
- `surface <id> create <window> <x> <y> <width> <height>` places a flipped layer-backed view above the
  window's WebViews; `surface <id> present <width> <height> <base64 RGBA>` replaces its pixels;
  `surface <id> close` removes it. A press records `surface-press <id> <x> <y>` in surface pixels.
- A frame whose decoded length is not `width × height × 4` is refused with `-3`.

## Grill Log

- **Q:** Why base64 for frames inside a record? **A:** Records from the program are text; a frame is
  a third larger encoded, which costs nothing next to presenting it, and keeps one channel for every
  command. A frame-rate surface belongs to the framebuffer desktop ([[architecture/NATIVE-UI]]).
- **Q:** Why non-blocking panels? **A:** A modal loop would stop the program's own pump; a panel with
  a completion handler leaves IPC and other windows answering while the person chooses.

## Dependencies and consumers

Uses [[Pudu Webview macOS Host]]; dispatched from [[Pudu Webview macOS Adapter]]; driven by
[[Std Desktop Native]].

## Referenced by

[[src/cbits/_MOC]] · [[architecture/DESKTOP-WEBVIEW]]
