---
type: module
path: "@root/cbits/pudu_webview_win.h"
fidelity: Active
tags: [module, runtime, desktop, webview, windows]
aliases: [Pudu Webview Windows Host]
---

# Pudu Webview Windows Host

The Windows adapter's private declarations: `PuduHandler`, one COM object template that forwards
`Invoke` to a function for every WebView2 completion and event interface; the window, view, pending
request and rule records; the process-wide host; and the helpers both translation units share
(events, UTF-8/UTF-16 conversion, refusal, fitting views).

## Grill Log

- **Q:** Why one template instead of a class per handler? **A:** WebView2 has a dozen handler
  interfaces that differ only in `Invoke`'s parameters; a template with those parameters as its
  arguments keeps each registration beside the code it runs.

## Referenced by

[[Pudu Webview Windows Adapter]] · [[Pudu Webview Windows View]]
