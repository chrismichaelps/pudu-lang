---
type: module
path: "@root/src/Pudu/Backend/Runtime/Kernel/Sort.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Column Sort]
---
# Native Column Sort

Export the family's runtime parts and their prerequisites.

Sort indices: valid rows ordered by value and then the null rows in row order, written as packed words. The order of valid rows is the one the interpreter's list sort produces: runs, then merges of two, three and four runs, asking the same comparisons.

## Resolved Grill Log

A plain stable sort differs when a column holds NaN, where the comparison is not an order. The merges are ported state by state, the empty trailing run included.

## Referenced by

[[Native Kernel Runtime]] · [[Native Builtin Kernels]]
