---
type: module
path: "@root/src/Pudu/Eval/Webview.hs"
fidelity: Active
tags: [module, runtime, desktop, webview]
aliases: [Eval Webview]
---

# Eval Webview

## Purpose and interface

The evaluator's side of the WebView record channel: `sendWebview`, `pumpWebview`,
`drainWebviewEvents`, `webviewRequestBody` and `respondWebview` call [[Pudu Webview Header]] and turn
its statuses into `IoOutcome`s. A target without an adapter answers every call with the
unsupported message.

## Semantics

- Failures are messages with a stable leading tag the Pudu side classifies: `unsupported:`,
  `thread:`, `malformed:`, `unknown:`, `gone:`, `platform:`, `invalid:`. A refused `send` appends the
  adapter's own reason.
- A pump is cut into slices of at most 16 milliseconds, between which the thread is back in the
  runtime: an interrupt is answered within a slice, and a watched stop request ends the pump early.
- Byte drains measure first and copy second; a queue that grows between the two only lengthens the
  next drain, and the copy is retried once with the new size.

## Grill Log

- **Q:** Why no token store, as the framebuffer desktop has? **A:** The adapter holds a single
  process-wide host whose ids the program chooses; a store here would duplicate that registry and
  could disagree with it.
- **Q:** Safe or unsafe foreign calls? **A:** The pump waits, so it is safe; the rest return at once
  and are unsafe, as the framebuffer adapter's are.

## Dependencies and consumers

Called from [[Eval Effect]]; consumed by [[Std Desktop Webview]].

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[architecture/DESKTOP-WEBVIEW]]
