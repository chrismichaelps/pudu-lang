---
type: module
path: "@root/src/Pudu/Backend/Runtime/Kernel/Buffer.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Buffer Kernels]
---
# Native Buffer Kernels

Export the family's runtime parts and their prerequisites.

The fourteen buffer primitives as `Pudu.Runtime.Buffer` answers them: allocation, fixed-width little-endian reads and writes, fill, compare, copy and the word scan. A write answers a new buffer; the operand is never changed.

## Resolved Grill Log

Bounds are separate tests so lowering builds the Option. Rejected: writing in place, which another holder of the bytes would see.

## Referenced by

[[Native Kernel Runtime]] · [[Native Builtin Kernels]]
