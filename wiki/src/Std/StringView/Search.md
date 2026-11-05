---
type: module
path: "@root/lib/Std/StringView/Search.pudu"
fidelity: Active
grammar: "[[grammar/pudu]]"
aliases: [Std StringView Search]
---
# Std StringView Search

## Purpose and interface

Pure UTF-8 byte-unit operations. Export compare, findLastFrom, findFirstOf,
findLastOf, findFirstNotOf, findLastNotOf, copyInto, Units and units. Operands
are Str, never StringView, avoiding an import cycle. Units implements
[[Std Iter]] Sequence[Int, UInt8] without staging an encoded array.

## Invariants and resolved Grill Log

Build a byte set from the needle once per set-search; offsets may point into
UTF-8 scalars. Forward positions are checked; reverse positions clamp to the
last byte. Nonempty bounded substring searches floor the prefix end to a
scalar boundary before calling the shared reverse primitive. Empty needles
return min(from, size), including interior-byte positions. Negative positions
refuse. copyInto clamps count to remaining bytes but refuses invalid source
positions, negative counts and insufficient destination capacity without any
write. Copy exact UInt8 values, without appending a terminator. No IO.

## Dependencies and consumers

[[Std StringView]] · [[Std Iter]] · [[Eval TextView]]

## Referenced by

[[src/Std/_MOC]] · [[Std Views Delivery]]
