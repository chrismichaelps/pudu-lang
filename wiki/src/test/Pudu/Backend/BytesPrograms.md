---
type: module
path: "@root/test/Pudu/Backend/BytesPrograms.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Bytes Programs]
---
# Backend Bytes Programs

Exports bytesSuccessPrograms and bytesRefusalPrograms.

Resolved Grill Log: every byte method on accented text's bytes and on an
empty sequence; clamped, reversed and oversized slice bounds; needles at both
ends, empty and absent; `toText` on valid text, a truncated sequence, an
overlong form, a surrogate, a value past U+10FFFF, a four-byte emoji, a stray
0xFF and an overlong three-byte form; range slices; ordering in tuples and
Bytes as map keys and set members. The refusals are range slices out of
bounds (counting bytes) and ending before they start.

`strided` covers whole and short final groups, zero width, offsets at and past the end, every malformed shape, an oversized stride and empty bytes (#846).

## Referenced by

[[Backend Module Programs]] · [[Backend Text Leak Tests]] · [[Native Bytes Runtime]]

## Boundary corpus

Resolved Grill Log: exercise all 256 byte values through array round-trips,
valid scalar UTF-8 boundary encodings and malformed continuation/truncation
cases, NUL bytes, unsigned key ordering and retained slices of temporary
concatenations. Explicit answers accompany interpreter comparisons.

Byte failure cases also cover accepted unary and binary operators at runtime,
preserving operand effects and exact diagnostic spans instead of E6001.

Frozen-byte cases cover invalid UTF-8, NUL, empty bytes, repeated reads,
slicing and Bytes nested in tuples and records. Runtime reconstruction uses
the same counted cleanup checks as ordinary byte values.

Argument-order and capture cases hold the receiver before arguments, check
that a closure retains a copied byte value after reassignment, and return a
shared byte reference as an owned result. Expected output records each effect.

Trailing and explicit Bytes entry returns print their hexadecimal value and
exit zero. Direct ordered operators retain E7001 even though Bytes order by
content inside tuples and ordered collection keys.

Resolved Grill Log (#828): Check receiver-first traces for direct operations and the guarded Option builder for at.
