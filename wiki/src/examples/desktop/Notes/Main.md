---
type: module
path: "@root/examples/desktop/Notes/Main.pudu"
fidelity: Active
aliases: [Notes Desktop Example]
tags: [module, example, desktop]
---
# Notes Desktop Example

A complete desktop application: typed `save`, streamed `count`, raw `reverse`, and `checkpoint`
commands; a `saved` event; a capability in code that grants exactly those commands and denies
`admin:*`; its frontend in `frontend/` and packaging in `pudu-desktop.toml`. With
`NOTES_SELF_TEST` set, the page exercises every IPC path and the process exits with the result,
which the gate and the packaged app both use as their live check.

## Referenced by

[[Desktop Webview Gate]] · [[architecture/DESKTOP-WEBVIEW]]
