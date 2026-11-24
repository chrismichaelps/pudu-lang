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

Resolved Grill Log. A different concrete native replacement can demand
wider storage. Observe it at the written path and replay the root binding
without altering unaffected members.

## Member receiver preparation

Resolved Grill Log: prepare a receiver as a read with an optional
place. If the receiver cannot be represented as a place, perform its
ordinary value read. Stop before any member work if a receiver
index transfers control. [[Compiler Lower Text]] · [[Compiler Lower Method]]

## Exact selected keys

Resolved Grill Log: retain every key once and check its exact
integer magnitude before narrowing for array access. A noninteger
alternative retains its own diagnostic. Validate at the read or
store so assignment still evaluates the replacement before reporting
an invalid destination. An earlier transfer suppresses later keys.

## Held slice keys in place reads

Resolved Grill Log: a position checked as an integer can hold a
range. Keep that key for read preparation and delegate its slice
bounds to [[Compiler Lower Slice]]. A range remains an invalid
assignment key, including when publishing a mutable final.

## Declaring writable pattern bindings

Resolved Grill Log. A named local and a destructured capture use the
same declaration rule. Mutable sites join the initializer and later
write layouts before allocating the slot. The captured initializer
runs once.

Resolved Grill Log: a store through a held key that may be a range always fails, so a value read through such a key never widens the element slot. Writeback through such a place narrows the returned value to the slot layout; a range key fails at the store before the value is read, and any other held layout reports the same assignment failure.
