---
type: module
path: "@root/src/Pudu/Compiler/Lower/Tuple.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Tuple]
---
# Compiler Lower Tuple

## Purpose and interface

Export lowerTuple, lowerTupleIndex and lowerTuplePattern.

- A tuple literal lowers its members left to right. A Never member stops
  there: the tuple becomes the earlier members' effects and is Never.
- `t[i]` needs the literal in-range position the checker already requires.
- `let (a, (b, _)) = subject` runs the subject once into a hidden `$pattern`
  local, then declares each name from its position. Tuple patterns of names,
  wildcards and tuples cannot fail on a tuple; any other pattern refuses.

## Grill Log

- **Q:** Where do a record pattern's field types come from now that records are named by identity? **A:** From the record's layout through `recordFields` (#525).

- **Q:** Why a hidden local instead of re-reading the subject? **A:** The
  subject runs exactly once, as `matchPattern` sees one value.
- **Q:** Why refuse a Never subject? **A:** There is no value to project and
  later reads of the names would have nothing to lower against; it stays an
  honest E6001 boundary.

## Generic records (#552)

Pattern update only: `CoreRecordType` has an argument list; behavior is unchanged.

## Referenced by

[[Compiler Lower Body]] · [[Native Tuple Delivery]] · [[src/_MOC]]

## Record patterns (#521)

`let {at: {x}, n: (_, last)} = subject` binds through field reads; `{x}` is
`{x: x}`. Named record patterns are refutable in `let`, so the checker never
hands them here.
