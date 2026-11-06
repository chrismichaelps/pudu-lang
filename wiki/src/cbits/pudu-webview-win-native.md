---
type: module
path: "@root/cbits/pudu_webview_win_native.cpp"
fidelity: Active
tags: [module, runtime, desktop, webview, windows, hybrid]
aliases: [Pudu Webview Windows Native]
---

# Pudu Webview Windows Native

## Purpose and interface

The `app menu`, `app dialog` and `surface` records of [[Pudu Webview macOS Native]] on Windows: a
Win32 menu bar on every window with an accelerator table the pump applies, the common file dialogs
and message boxes, and a child window presenting Canvas frames.

## Semantics

- `cmd` and `ctrl` both mean Ctrl; the chord is shown after the item's title.
- File dialogs and message boxes are modal: the record returns once the person answers, and the
  answer is queued as `dialog-ok` or `dialog-cancel`. Message boxes offer the platform's one, two or
  three button sets; the index answered maps to the program's buttons in order.
- A surface converts frames to the platform's BGRA order, scales without smoothing, sits above the
  window's views, and reports presses in frame pixels.

## Grill Log

- **Q:** Modal dialogs here but not elsewhere? **A:** The platform's common dialogs run their own
  message loop, which keeps WebViews and other windows painting and queuing events; only the program
  waits, exactly as long as the person does.

## Dependencies and consumers

Uses [[Pudu Webview Windows Host]]; dispatched from [[Pudu Webview Windows Adapter]].

## Referenced by

[[src/cbits/_MOC]]
