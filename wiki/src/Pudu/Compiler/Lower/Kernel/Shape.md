---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Compiler/Lower/Kernel/Shape.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Kernel Shape]
---
# Compiler Lower Kernel Shape

Export the description of a kernel builtin: its operands, its guards and how
its answer is formed. [[Compiler Lower Kernel]], [[Compiler Lower Kernel Host]]
and [[Compiler Lower Kernel Lanes]] build their tables from it.

## Resolved Grill Log

The description is data, so the direct call and the callable body of a
builtin are one builder over one row.

## Referenced by

[[Compiler Lower Kernel]] · [[Compiler Lower Kernel Host]] · [[Compiler Lower Kernel Lanes]]
