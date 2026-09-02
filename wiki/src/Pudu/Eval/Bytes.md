---
type: module
path: "@root/src/Pudu/Eval/Bytes.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
tags: [module, runtime, bytes]
aliases: [Eval Bytes]
---
# Eval Bytes
## Purpose
Own the compact runtime representation and built-in operations for Pudu `Bytes` values.
## Interface
Constructs bytes from text/arrays and dispatches length, slice, search, conversion, concat, and
reverse operations as total evaluator results.
## Governance and algorithm
Uses strict `ByteString`; bounds answer options or clamped slices according to the public contract;
UTF-8 decoding reports failure rather than replacement text.
## Grill Log
- **Q:** Store bytes as evaluator arrays? **A:** No. _Rationale:_ it multiplies per-byte allocation
  and prevents cheap native slicing/search. _Rejected:_ partial indexing.
## Referenced by
[[src/Pudu/Eval/_MOC]] · [[Std Bytes]] · [[Eval Value]]
