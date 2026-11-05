---
type: module
path: "@root/test/Pudu/Backend/ArrayPrograms.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Array Programs]
---
# Backend Array Programs

Exports arraySuccessPrograms and arrayRefusalPrograms, for [[Native Arrays]].

Resolved Grill Log: every runtime method with its boundaries (clamping,
no-ops, -1); a variable updated in place beside copies taken before each
update, and a 2000-item build loop; `map`, `filter` and `reduce` with
callbacks that print, showing order and count; arrays of records, nested
arrays, equality and ordering inside tuples, `for` over records; an entry
returning an array. The refusals are `get` past the end (at the call), a
negative index (at the index), ordering arrays (E7001) and an overflow inside a
callback.

## Referenced by

[[Native Arrays]] · [[Backend Module Programs]] · [[Backend Text Leak Tests]]
