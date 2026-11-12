---
type: module
path: "@root/lib/Std/Desktop/Webview.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, desktop, webview]
aliases: [Std Desktop Webview]
---

# Std Desktop Webview

## Purpose and interface

Windows and WebViews as values. `newWindow` and `newView` build specifications; `openWindow` and
`createView` turn them into command records; the command builders (`navigate`, `evaluate`,
`reload`, `setBounds`, `setZoom`, `openDevtools`, `setTitle`, `setSize`, `showWindow`, `closeView`,
`closeWindow`, and the rest) each answer one record. `send` applies records, `pump` runs the platform
loop, `events` drains and decodes events, `body` reads a pending request's body and `respond`
finishes it. `decodeEvents` is the pure decoder, so event handling is testable without a display.

## Semantics

- Every failure is a `WebviewError` classified from the runtime's tagged message:
  `Unsupported`, `NotMainThread`, `Malformed`, `UnknownTarget`, `RequestGone`, `Invalid`, `Platform`.
- A view with no frame fills its window and follows its size. Zoom is in thousandths (`1000` is
  100%), the same fixed-point convention the framebuffer desktop uses for density.
- `createView` always ends with `realize`, so configuration cannot be sent after creation by
  accident.
- An event the decoder does not know is kept as `Unknown` with its verb, never dropped, so a newer
  adapter cannot silently lose information against an older library.
- Request headers are decoded with lower-cased names; `header` finds one.

## Grill Log

- **Q:** Should commands be sent one call each? **A:** No: command builders answer records and
  `send` takes an array, so creating a window and its WebViews is one boundary crossing and fails or
  succeeds as a unit up to the first refused record.
- **Q:** Why does the program choose ids? **A:** A batch refers to the window it opens; ids chosen by
  the platform would need a round trip per object. [[Std Desktop App]] allocates them.

## Dependencies and consumers

Uses [[Std Desktop Records]] and the prelude `webview*` effects ([[Eval Webview]]). Consumed by
[[Std Desktop App]], [[Std Desktop Protocol]] and [[Std Desktop Ipc]].

## Referenced by

[[src/Std/_MOC]] · [[architecture/DESKTOP-WEBVIEW]]

Resolved Grill Log: decode window-state, scale, theme, inspector and file-drop events through the
existing factory table. File-drop interception is opt-in before realization.

Resolved Grill Log: file-drop paths occupy one JSON-array field, preserving embedded newlines and Unicode filenames.

Resolved Grill Log: successful data clearing retains `data-cleared <view>`; asynchronous failure is `data-clear-failed <view> <detail>` and decodes to `DataClearFailed`, preserving failure information rather than producing Unknown.

Resolved Grill Log: a view whose native admission is refused after `realize` returned reports
`refused <view> <unsupported|platform> <reason>`, decoded as `Refused(view, Unsupported)` or
`Refused(view, Platform(reason))`. It is distinct from `Crashed`: a crashed view was admitted and
may be reloaded, while a refused view was closed by the adapter and never ran. An unrecognized
status word decodes as `Platform` so the refusal is never lost.
