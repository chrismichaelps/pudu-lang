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

## Dynamic fields (#846)

A record or record variant whose declared field is `dynamic` widens the
written value of an implementing type to the declared type before building the
Core record. Resolved Grill Log: the declaration's field type, not the
initializer's, chooses the widening.

## Dynamic fields in record updates (#956)

Resolved Grill Log: project each written replacement through the checked
layout of the retained base. Record updates reuse the same field widening
as construction and still evaluate the base before the written fields.

## Runtime layouts in products (#956)

Resolved Grill Log: Build records using their actual field layouts. An update preserves the base layout of untouched fields and may widen written fields. Field reads select the held carrier.

## Runtime layouts in sum payloads (#956)

Resolved Grill Log: Record-style variants reuse the sum payload construction after evaluating fields in source order.

Resolved Grill Log. Use a represented concrete field layout after
trying the checked projection. A record update retains untouched
fields and settles each written replacement independently.

## Held record update base

Resolved Grill Log. Evaluate the base and all written replacements
before testing the held base. A held record keeps its owner and
fields. A written replacement for a missing field runs for its
effects. A non-record base reports the evaluator's E7001 at the
update after the field effects, unless an operand already transferred.

## Held member reads

Resolved Grill Log. A member read selects the held layout and reads
its field, including fields of a named sum variant. A held field
takes priority over a declared method. Preserve the actual result
layout and the receiver's missing-member diagnostic.

Resolved Grill Log. When the held receiver has a builtin member instead
of a field, use [[Compiler Lower Method Value]] to form the closure from
the held receiver's signature and layout.
