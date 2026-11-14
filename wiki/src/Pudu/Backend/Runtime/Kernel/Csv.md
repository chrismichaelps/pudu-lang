---
type: module
path: "@root/src/Pudu/Backend/Runtime/Kernel/Csv.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native CSV Kernels]
---
# Native CSV Kernels

Export the family's runtime parts and their prerequisites.

The delimiter test and the record scan as `Pudu.Eval.Csv` answers them: complete records at the front of a buffer, the bytes and characters they span, or nothing when a field is not valid text.

## Resolved Grill Log

Fields are decoded once when they end; a quote in the last byte leaves its record incomplete.

## Referenced by

[[Native Kernel Runtime]] · [[Native Builtin Kernels]]
