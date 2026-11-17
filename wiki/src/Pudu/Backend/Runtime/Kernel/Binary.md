---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Runtime/Kernel/Binary.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Binary Kernels]
---
# Native Binary Kernels

Exports the C11 runtime parts for `binaryEncode` and `binaryDecode`.
Both operations use the wire form in [[Eval Binary]]. The writer preserves
first-use name indexes, field order, integer and binary64 bits, and the
512-level nesting limit. The reader builds `Record` and `Picked` using the
typed `Map[Str, Node]` helpers supplied by [[Backend Emit Kernel]].

## Resolved Grill Log

Validate the name table, the tree and trailing bytes before allocating
result boxes. Resolve duplicate field names by spelling even when the wire
table assigns different indexes to the same name. The writer frees temporary
storage on both paths. Lowering turns writer refusal into E7001 at the call
site and reader refusal into `Err(Str)` through [[Native Host State]].

## Referenced by

[[Backend Module Map]] · [[Native Kernel Runtime]] · [[Native Builtin Kernels]] · [[Backend Kernel Programs]]
