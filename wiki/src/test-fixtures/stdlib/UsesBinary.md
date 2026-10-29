---
type: module
path: "@root/test-fixtures/stdlib/UsesBinary.pudu"
fidelity: Active
aliases: [Std Binary Fixture]
tags: [module, test, stdlib, serialization]
---
# Std Binary Fixture

One record derives both binary Encode/Decode and JSON Encode/Decode and executes both paths.

Checks [[Std Binary]] round trips for `Int` extremes, `Float64` bit patterns (a NaN payload,
signed zero, infinities), including contiguous arrays and lane blocks, multilingual text, nested arrays, options, contiguous float arrays,
flags and a derived record holding every field kind, including `Lanes` and a sum; golden bytes for
a whole node and a one-field record; a renamed field and a skipped one; a skipped sum field both absent and supplied on the wire; a missing text field
refused rather than read as empty; evolution where an added optional field reads as `None`, an
old reader ignores a new field and a missing field reports its path through an array element;
and refusals for truncation, trailing bytes, an unknown node tag, a name index past the table, a
repeated field, a wrong node kind, an unknown variant, a foreign magic, a future version and a
checksum mismatch. Answers the number of check groups, 22.

## Referenced by

[[Std Binary]] · [[Eval Binary]]

## Resolved Grill Log

- **Q:** Compare floating arrays with equality? **A:** No; assert every UInt64 bit pattern after
  typed array and lane round trips, because NaN is unequal and signed zeros compare equal.
- **Q:** Replace evolution/refusal assertions with a count? **A:** No; each group asserts its
  full value/error/path before returning the aggregate count.
