---
type: module
path: "@root/test/native/WebviewDrive.c"
fidelity: Active
aliases: [Webview GTK Harness, Webview Drive Harness]
tags: [module, test, desktop, webview]
---
# Webview Drive Harness

Drives whichever adapter it is linked with through the six entry points: opens a window with a
filling view and a second view at a fixed frame (which must report its own title), the first that injects a script and posts `ping` to the `pudu` scheme, answers `pong`, waits for the page
title, evaluates `document.title` with the injected value and requires `done:pong:42`, then
navigates outside the allowlist and requires `navigation-blocked`. A content rule blocks a fetch of
`pudu://app/blocked` before it reaches the program, and the page reports the refusal in its call,
which also shows the page loaded only after the rule list compiled. On every platform it also installs a
menu bar and requires a native surface to accept a frame of its size, refuse one of another size,
and close. CI links it with the macOS
adapter and with the WebKitGTK adapter under a virtual display.

## Referenced by

[[Desktop Webview CI]] · [[Pudu Webview macOS Adapter]] · [[Pudu Webview GTK Adapter]]
