---
type: module
path: "@root/src/Pudu/Compiler/Lower/Tuple.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Tuple]
---
# Compiler Lower Tuple

## Purpose and interface

Export lowerTuple and lowerTuplePattern.

- A tuple literal lowers its members left to right. A Never member stops
  there: the tuple becomes the earlier members' effects and is Never.
- `t[i]` uses [[Compiler Lower Slice]] for its checked literal position.
- `let (a, (b, _)) = subject` runs the subject once into a hidden `$pattern`
  local, then declares each name from its position. Tuple patterns of names,
  wildcards and tuples cannot fail on a tuple; any other pattern refuses.

## Grill Log

- **Q:** Where do a record pattern's field types come from now that records are named by identity? **A:** From the record's layout through `recordFields` (#525).

- **Q:** Why a hidden local instead of re-reading the subject? **A:** The
  subject runs exactly once, as `matchPattern` sees one value.
- **Q:** What if the subject is Never? **A:** Evaluate it at its written
  location. The block stops before any bindings or later statements need
  to lower.

## Generic records (#552)

Pattern update only: `CoreRecordType` has an argument list; behavior is unchanged.

## Referenced by

[[Compiler Lower Body]] · [[Native Tuple Delivery]] · [[src/_MOC]]

## Record patterns (#521)

`let {at: {x}, n: (_, last)} = subject` binds through field reads; `{x}` is
`{x: x}`. Named record patterns are refutable in `let`, so the checker never
hands them here.

## Runtime layouts in products (#956)

Resolved Grill Log: Keep actual tuple member layouts through binding and indexing. A checked annotation still supplies the source type. A boxed tuple is indexed by selecting its held layout first.

## Tuple-checked bracket reads

Resolved Grill Log: [[Compiler Lower Slice]] owns indexing, including
the literal slot fast path for tuples. A tuple-checked receiver can
hold a different indexable value. A shorter held tuple uses the
runtime bounds diagnostic.

## Selected destructuring subjects

Resolved Grill Log: evaluate the subject once, test each held shape,
and publish bindings only after the entire pattern succeeds. Join
different successful layouts by binding position. Report E7013 at
the whole pattern using the original subject's runtime kind.
