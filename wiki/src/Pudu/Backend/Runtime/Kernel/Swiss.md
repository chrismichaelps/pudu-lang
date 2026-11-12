---
type: module
path: "@root/src/Pudu/Backend/Runtime/Kernel/Swiss.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Flat Table Kernels]
---
# Native Flat Table Kernels

Export the family's runtime parts and their prerequisites.

The flat table over two stores, as `Pudu.Eval.SwissTable` answers it: the rounded capacity, the slot a key is found at, insert with rehash at three quarters load, and delete leaving a tombstone. Control bytes live eight to a word in the control store; a missing word reads as all empty.

## Resolved Grill Log

Arithmetic is the interpreter's 64-bit arithmetic, so a table record built by hand behaves alike. The stores stay persistent trees; the runtime is generic over their tree operations.

## Referenced by

[[Native Kernel Runtime]] · [[Native Builtin Kernels]]
