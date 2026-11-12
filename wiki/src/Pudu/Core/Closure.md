---
type: module
path: "@root/src/Pudu/Core/Closure.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Core Closure Identities]
---
# Core Closure Identities

Own the closure identities that lowering writes and emission reads. A text
method is `toText` taken as a value from a receiver whose type declares no
`toText`; its site starts with `textMethodPrefix`, and `isTextMethod` reads it
back. No execution, inference or C spelling.

## Resolved Grill Log

- **Q:** Mark a text method with a new field on `CoreClosureInfo`? **A:** No; the
  site prefix. _Rationale:_ the site is already the closure's identity and
  equality reads it; every constructor of the record would otherwise change.
  _Rejected:_ deciding it in emission from the receiver's type (a record or sum
  with a declared `toText` renders as its function).
- The interpreter renders the value `<method toText>` and names it `text method`
  whatever the receiver; two are equal when their receivers are.

## Referenced by

[[Pudu Core IR Module]] · [[Compiler Lower Method Value]] · [[Native Aggregate Emission]]
