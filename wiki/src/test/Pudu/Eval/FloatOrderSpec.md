---
type: module
path: "@root/test/Pudu/Eval/FloatOrderSpec.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, test, runtime]
aliases: [Eval Float Order Tests]
---

# Eval Float Order Tests

## Purpose and interface

Export floatOrderProperties: `compareValues` on NaN, numbers, an Int and the
signed zeros, and one program run through the tree walker and with compiled
bodies covering tuple ordering with NaN members, a map keyed by such tuples,
and the unchanged IEEE scalar operators.

## Grill Log

- **Q:** Why check the scalar operators too? **A:** The repair is to the key
  order only; `n < 1.0` and `n == n` must still be false.

## Referenced by

[[Eval Value]] · [[test/Main]] · [[src/_MOC]]
