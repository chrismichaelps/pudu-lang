---
type: module
path: "@root/scripts/desktop-bridge.mjs"
fidelity: Active
aliases: [Desktop Bridge Generator]
tags: [module, tooling, desktop]
---
# Desktop Bridge Generator

Writes [[Std Desktop Bridge]] from [[Pudu JS Bridge]] and [[Pudu JS Bridge Declarations]], one
string per source line with backslashes, quotes, braces and tabs escaped; `--check` fails when the
committed module differs from what the sources produce.

## Referenced by

[[Desktop Webview Gate]] · [[Desktop Webview CI]]
