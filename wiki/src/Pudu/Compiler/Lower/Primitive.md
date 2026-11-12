---
type: module
path: "@root/src/Pudu/Compiler/Lower/Primitive.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Primitive]
---
# Compiler Lower Primitive

Export lowerPrimitiveCall: the direct call of a prelude primitive that is
not a local, a function or a variant. It tries, in order, the text-view,
Decimal, word-map, store, kernel and flat-table primitives and answers
Nothing for any other name.

## Resolved Grill Log

One dispatcher keeps [[Compiler Lower Body]] below its size bound and keeps
the order of the families in one place. No name is claimed twice.

## Referenced by

[[Compiler Lower Body]] · [[Native Builtin Kernels]]
