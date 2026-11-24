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

## Str, tuples and payloads (#562)

Adds `for` over accented text, a tuple, `Some`, `None` and one- and
two-field variants, and `charFromCode` at 97, a surrogate, one past the last
scalar, a negative, an emoji and NUL (which `show` writes raw).

## Referenced by

[[Backend Module Programs]] · [[Backend Text Leak Tests]]

## Held sequence state and results

Resolved Grill Log. Cover a changed state carrier passed to the next
advance after a binder skip. Compare the complete runtime diagnostic
for an advance result with a malformed payload, and preserve effects
before a transfer from a sequence method. [[Compiler Lower For]]

Resolved Grill Log. A record literal iterated directly is written in parentheses so the loop body is not read as its fields.
