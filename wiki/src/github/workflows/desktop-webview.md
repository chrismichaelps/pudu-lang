---
type: module
path: "@root/.github/workflows/desktop-webview.yml"
fidelity: Active
aliases: [Desktop Webview CI]
tags: [module, test, delivery, desktop]
---
# Desktop Webview CI

For changes to the WebView adapters, their native tests, or the page bridge: on macOS, run
[[Webview Records Test]], link [[Webview Drive Harness]] with the WebKit adapter and run it, and run
the bridge tests with the generator check; on Ubuntu 24.04, install WebKitGTK and a virtual
display, run the records test, and link the harness with [[Pudu Webview GTK Adapter]] under
`xvfb-run`. No compiler build is needed: the adapters are plain native code.

## Resolved Grill Log

- **Q:** Why not drive the GTK adapter through the compiler? **A:** The harness exercises the same
  six entry points the evaluator calls, in minutes and without a WebKitGTK-flagged compiler build;
  the evaluator's side of the boundary is already covered on macOS by the live gate.

## Referenced by

[[github/workflows/ci]] · [[architecture/DESKTOP-WEBVIEW]]
