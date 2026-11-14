---
type: module
path: "@root/src/Pudu/Backend/Runtime/Kernel/Column.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Column Kernels]
---
# Native Column Kernels

Export the family's runtime parts and their prerequisites.

The column kernels as `Pudu.Runtime.Column` answers them: sums, extremes, threshold filters, projection, addition, bitmap algebra and count, binary search and gather over packed 64-bit rows and validity bitmaps. A read outside a buffer counts as an invalid row or a zero word, as the interpreter's reads do.

## Resolved Grill Log

Float extremes use the interpreter's `<=` selection, so NaN and signed zero answer alike. Tuple results are built as boxes of three or two cells.

## Referenced by

[[Native Kernel Runtime]] · [[Native Builtin Kernels]]
