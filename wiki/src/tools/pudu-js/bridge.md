---
type: module
path: "@root/tools/pudu-js/bridge.js"
fidelity: Active
aliases: [Pudu JS Bridge]
tags: [module, desktop, ipc, javascript]
---
# Pudu JS Bridge

The page side of the IPC layer, injected at document start into each view's main frame and applied
to `{ key, label, dev }`: `invoke(command, args, { channel })` posts JSON or bytes to
`pudu://app/.pudu/ipc/<command>` with the invoke key and the origin captured when the bridge was
injected and answers the decoded result or rejects with
a `PuduError`; `listen`, `once` and `emit` carry events; `Channel` receives streamed messages; in
development, console errors, uncaught errors and unhandled rejections are forwarded. The installed
`window.__pudu` is frozen and non-configurable, and the key is never a property of it. Its
declarations live in `bridge.d.ts`.

## Grill Log

- **Q:** Why does the channel travel in a header rather than inside the arguments? **A:** The
  arguments decode into the command's declared type; a channel inside them would need every argument
  type to know about channels. A header keeps arguments plain data and gives the program the channel
  as its own typed parameter.

## Referenced by

[[Std Desktop Bridge]] · [[Desktop Bridge Generator]]
