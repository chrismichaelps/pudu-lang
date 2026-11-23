---
type: module
path: "@root/src/Pudu/Compiler/Lower/Place.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Place]
---
# Compiler Lower Place

Export lowerPlaceAssignment. Parse a target into a root local and field and
index steps; hold each index, then the value, in temporaries; assign the
root the rebuilt value. Field steps use CoreRecordUpdate, index steps read
with ArrayGetAt and write with ArrayReplaceAt, both at the root span.
Failures of an assignment or a lent `&mut` argument report at the root name; a
lent receiver reads its elements with readHeldAtKeys (see Held places).
Nothing for a target that is not a place of a local.

## Resolved Grill Log

Moved here from Compiler Lower Record's field assignment, which it now
covers. Index temporaries make each index run once, in the evaluator's
order. See [[Native Place Assignment]].

## Referenced by

[[Compiler Lower Body]] · [[src/Pudu/Compiler/_MOC]]

## Held places (#651)

Also export HeldPlace, holdPlace, readHeld, readHeldAtKeys and storeHeld. holdPlace resolves
a target, `*` included, and runs its indices into held locals; readHeld reads
it at the root span, and readHeldAtKeys reads each element at its own key span;
both run through readHeldBy. storeHeld stores through it at the root span, reading the root as it
is at the store. Assignment uses the same three, and `*value = x` assigns the
local itself. A plain name still goes to [[Compiler Lower Body]]'s own case.
Resolved Grill Log: [[Compiler Lower Loan]] lends places with them.

## Dynamic destinations (#956)

Resolved Grill Log: widen the replacement to the held place's carrier after
its indices run. The root is still read at writeback, after the replacement
has evaluated. A Never replacement keeps its original control transfer.

## Runtime alternatives at a held place (#956)

Resolved Grill Log: a replacement projects to the layout of the held
place before a store. Tagged values are unpacked and tagged again when
their carrier is narrower than the place's carrier.

## Mutable slot layout discovery (#956)

Resolved Grill Log: A write to a field or array element can demand a wider root layout. It records the changed path and keeps the layouts of unaffected fields.
