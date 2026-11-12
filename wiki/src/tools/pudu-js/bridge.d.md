---
type: module
path: "@root/tools/pudu-js/bridge.d.ts"
fidelity: Active
aliases: [Pudu JS Bridge Declarations]
tags: [module, desktop, ipc, typescript]
---
# Pudu JS Bridge Declarations

The TypeScript surface of [[Pudu JS Bridge]]: `PuduErrorKind`, `PuduError`, `Channel<T>`,
`PuduEvent<T>`, `PuduBridge`, and the global `window.__pudu`. Every module `pudu desktop types`
writes begins with these declarations. A call's `channel` option asks only for the channel's `id`,
which is all the bridge reads, so a `Channel<number>` is accepted although `Channel` is invariant in
its message type.

## Referenced by

[[Std Desktop Bridge]] · [[Std Desktop Ipc]]

Resolved Grill Log: PuduWindow, PuduWindowState and PuduDrop describe the window controls and
events, preserving the existing generic invoke/channel contract.

Resolved Grill Log: `state()` documents last-observed snapshot semantics and requests a native refresh.
