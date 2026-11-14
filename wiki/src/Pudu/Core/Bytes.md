---
type: module
path: "@root/src/Pudu/Core/Bytes.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Core Byte Operations]
---
# Core Byte Operations

Own the closed CoreBytesMethodName enum, reexported unchanged through Pudu.Core.
No execution, inference or C spelling.

## Resolved Grill Log

Extract the existing enum to keep Core.hs below 500 lines; existing constructors
keep their names. `BytesStridedOf` gathers `width` bytes from each `stride`-byte
group from `offset` and takes a shape already checked by lowering
(0 <= width <= stride, stride >= 1); an offset past the end gives no bytes and a
final short group gives what remains, as `Eval.Bytes` answers.

## Referenced by

[[Pudu Core IR Module]] · [[Compiler Lower Bytes]] · [[Backend Emit Bytes]]
