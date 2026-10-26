---
type: module
path: "@root/src/Pudu/Backend/Emit/Array.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Emit Array]
---
# Backend Emit Array

`arrayHelpers` writes the helpers one array type needs: drop, copy, make, the
updating methods, get, index_of, contains, show, equal, compare and
comparable. Each answers with a new reference. An update changes the buffer in
place only when the box has one owner (it grows the buffer and retains the
box), and copies it otherwise.

## Resolved Grill Log

- The edge cases are `Eval.Array`'s: insert and slice clamp, `pop` of nothing
  and `remove` out of range answer the array unchanged, `indexOf` answers -1.
- Ordering is `compareLists`: the first differing item decides, then the
  length. Equality is the members' own.

## Referenced by

[[Backend Emit Aggregate]] · [[Native Arrays]]
