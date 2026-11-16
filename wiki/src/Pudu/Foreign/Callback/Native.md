---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Foreign/Callback/Native.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Foreign Callback Native Adapter]
---

# Foreign Callback Native Adapter

Marshal validated callback signatures into [[Pudu FFI Callback Bridge]].
The adapter publishes a native function and context pair while keeping its
stable pointer behind the bridge's generation lookup.

## Resolved Grill Log

- Decode record arguments with the same offsets and leaf reconstruction as
  [[Foreign Call]]. Incoming pointer storage is used only during invocation.
- Separate the immutable signature's code pointer from the live generation.
  Cache each native context by its logical registration generation for the
  run. Release the stable pointer through the native retirement hook after the
  last invocation leaves. No late callback can dereference the pointer.
- Return a native fallback on a host exception at the foreign export.
  Evaluator failures are recorded by the invocation handler before this
  final boundary.

## Referenced by

[[src/Pudu/Foreign/_MOC]] · [[Pudu FFI Callback Bridge]] · [[Foreign Callback Delivery]]
