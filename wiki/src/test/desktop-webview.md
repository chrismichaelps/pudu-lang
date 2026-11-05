---
type: module
path: "@root/test/desktop-webview.mjs"
fidelity: Active
aliases: [Desktop Webview Gate]
tags: [module, test, desktop, webview]
---
# Desktop Webview Gate

## Purpose and algorithm

Run [[Desktop Modules Fixture]] and require every check to pass; run the bridge's own tests
([[Pudu JS Bridge Test]]) and require [[Desktop Bridge Generator]] to find the embedded module
unchanged; generate the Notes example's TypeScript module and require its typed commands, stream
and events, and type-check it with `tsc --strict` where installed; compile and run
[[Webview Records Test]]; serve [[Desktop Updates Fixture]]'s release over a local HTTP server and
require every update outcome line; run [[Desktop Packages Fixture]] and validate its `.deb` with
`dpkg-deb`, its `.rpm` with `rpm -K` and `rpm -qlp`, its NSIS installer when `makensis` can compile
a probe script, and its MSI when `wix` exists. On macOS with `PUDU_DESKTOP_DRIVE=1`, run the Notes
example's self-test in a live WebView.

## Grill Log

- **Q:** Why probe `makensis` with an empty script before trusting it? **A:** A broken installation
  can answer its version and still crash on any input; the probe tells a broken tool from a broken
  generated script, and CI on Linux, where the tool works, always requires the installer.

## Referenced by

[[Repository Gates]] · [[Std Desktop App]] · [[architecture/DESKTOP-WEBVIEW]]
