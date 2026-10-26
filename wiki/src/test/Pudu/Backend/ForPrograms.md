---
type: module
path: "@root/test/Pudu/Backend/ForPrograms.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend For Programs]
---
# Backend For Programs

Exports forSuccessPrograms (label, source, expected stdout) and
forRefusalPrograms (label, source).

Resolved Grill Log: exclusive and inclusive ranges, including empty, reversed
and single-element ones, with effects in both ends; ranges that end at the
largest `Int` and start at the smallest; nested labelled loops with `break`
and `continue`; a literal binder that skips non-matching elements; a sequence
walked to `None`, an empty one, and a `return` from inside a sequence loop.
The refusal is an overflow inside a range body, after the elements before it
printed.

## Referenced by

[[Backend Module Programs]] · [[Backend Text Leak Tests]]
