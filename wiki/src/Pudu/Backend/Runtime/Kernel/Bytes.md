---
type: module
path: "@root/src/Pudu/Backend/Runtime/Kernel/Bytes.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Kernel Bytes]
---
# Native Kernel Bytes

Export the family's runtime parts and their prerequisites.

Shared byte helpers: an Int as a signed word, a checked span inside a view, little-endian word reads and writes, a fresh buffer and a copy of a view to write into.

## Resolved Grill Log

Offsets are compared without adding to them, so no bound check can wrap.

## Referenced by

[[Native Kernel Runtime]] · [[Native Builtin Kernels]]
