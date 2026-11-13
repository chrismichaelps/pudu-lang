---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Runtime/Host/Desktop.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Host Desktop]
---

# Native Host Desktop

Emits the desktop host outcomes and selects the packaged AppKit sources.
The runtime translates typed cells to the existing adapter C ABI. Each
window gets a token valid until explicit close or process teardown.

## Resolved Grill Log

Match the interpreter's validation and status order, preserve adapter
main-thread checks, and keep the window registry serialized under the
native run gate. Non-macOS branches return the interpreter's unsupported
outcome without reaching an adapter. The macOS branch drains registered
windows during normal or controlled process exit.

## Referenced by

[[src/Pudu/Backend/_MOC]] · [[Native Desktop Adapter Delivery]] · [[Native Host Runtime]]
