---
type: module
path: "@root/test/Pudu/Backend/TextCollectionPrograms.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Text Collection Programs]
---
# Backend Text Collection Programs

Exports textCollectionSuccessPrograms and textCollectionRefusalPrograms.

Resolved Grill Log: `split` with repeated, leading and trailing separators,
overlapping candidates (`"aaa".split("aa")`), multi-byte separators and
pieces, an empty separator and empty text; `lines` with trailing, doubled and
lone newlines and `\r\n`; `chars` with accented letters and an emoji; pieces
used in loops, joins and indexing. `toInt` and `toFloat` over signs alone,
leading zeros, the Int limits and one past them, surrounding space,
underscores, non-ASCII digits, `.5`, `5.`, six- and seven-digit exponents,
overflow to infinity, the largest double and one past it, denormals and
underflow, and negative zero. The refusal indexes past a split's pieces. The
interpreter's `show` leaves `\r` raw, and the expected text keeps that byte.

## Referenced by

[[Backend Module Programs]] · [[Backend Text Leak Tests]] · [[Native Text Pieces]] · [[Native Text Number]]
