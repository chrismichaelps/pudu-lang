---
type: module
path: "@root/test/Pudu/Backend/ArrayPatternPrograms.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Array Pattern Programs]
---
# Backend Array Pattern Programs

Exports arrayPatternSuccessPrograms and arrayPatternRefusalPrograms, for
[[Native Arrays]].

Resolved Grill Log: `sortBy` with a comparison that prints every question,
over mixed, sorted, reversed, empty, single and 300-item inputs, a stability
check on records and a Str comparison; sequence patterns with exact lengths,
bound and skipped rests, back items, guards, records, nested sequences, and
patterns inside tuples, variants and `for` bodies whose arms print; every
range shape on arrays and on Str with accented characters, empty slices, a
slice of a slice and side-effecting ends. The refusals are a slice past the
end, an end before the start, a Str slice counting characters, a negative
start on an empty array, and a Str index past the end.

## Referenced by

[[Native Arrays]] · [[Backend Module Programs]] · [[Backend Text Leak Tests]]
