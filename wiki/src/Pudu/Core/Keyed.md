---
type: module
path: "@root/src/Pudu/Core/Keyed.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Core Keyed Operations]
---
# Core Keyed Operations

Own the closed CoreKeyedMethodName enum, reexported unchanged through Pudu.Core.
Include the four word-map algebra tags. No execution, inference or C spelling.

## Resolved Grill Log

Extract the existing enum to keep Core.hs below 500 lines. Existing constructors
retain their names; new word operations require Map[K, UInt64] operands/results.
There is no persisted Core ordinal or change to the frame-cell layout.

## Referenced by

[[Pudu Core IR Module]] · [[Compiler Lower Word Map]] · [[Backend Frame Values]]
