---
type: module
path: "@root/src/Pudu/Compiler/Lower/Record.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Record]
---
# Compiler Lower Record

## Purpose and interface

Export lowerRecord, lowerRecordUpdate, lowerField and lowerFieldAssignment.

- A record literal takes its type from the checker's facts for its span, and
  lowers the written fields in written order (shorthand `{x}` reads the local
  `x`). A Never field stops the record after the fields before it ran.
- `Name{..base, f: v}` runs the base first, then the written fields.
- `r.f` reads a declared field of a record value.
- `local.a.b = value` runs the value into a hidden `$assigned` local, then
  stores the local's current value with that path replaced. The value may
  itself assign the local, and the interpreter stores into what the local
  holds after it ran, so the read comes second.

Only records the root module declares, without type parameters, have a native
layout; [[Compiler Lower Types]] forms them from [[Type Boundary]]'s
`declaredRecords`.

## Grill Log

- **Q:** Is `Box{w: 1, h: 2}` a record or a variant? **A:** Whatever the checker typed the span as: a record type builds `CoreRecord`, a sum with a record variant of that name builds `CoreConstruct`. Field types come from the record's layout (#525).

- **Q:** Why rebuild the record on field assignment instead of writing into
  the box? **A:** Records are values; another binding may share the box.
  Rebuilding is the interpreter's semantics with no aliasing question.
- **Q:** Why read the local after the value? **A:** Probed: `p.x = { p =
  Point{x: 10, y: 20}; 7 }` stores `Point{x: 7, y: 20}` in both evaluators.

## Generic records (#552)

Pattern update only: `CoreRecordType` has an argument list; behavior is unchanged.

## Referenced by

[[Compiler Lower Body]] · [[src/_MOC]]

## Place assignment (#649)

lowerFieldAssignment moved to [[Compiler Lower Place]] as lowerPlaceAssignment.
