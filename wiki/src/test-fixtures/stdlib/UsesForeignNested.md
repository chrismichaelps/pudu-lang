---
type: module
path: "@root/test-fixtures/stdlib/UsesForeignNested.pudu"
fidelity: Active
grammar: "[[grammar/pudu]]"
aliases: [Uses Foreign Nested]
---

# Uses Foreign Nested

Run nested by-value foreign calls against the C++ fixture. The entry returns
the number of checks that hold. It covers homogeneous floating records, mixed
alignment, nested tail padding in an argument and result, and output slots.

## Resolved Grill Log

Use a Float64 and UInt8 in the inner struct, with another UInt8 after it in
the outer struct. The trailing field crosses at the end of the complete inner
object. A wider nested result also checks that the 32-member limit applies per
record even when the full tree contains more than 32 leaves.

## Referenced by

[[src/_MOC]] · [[Nested Foreign Record Delivery]] · [[Pudu FFI Bridge]]
