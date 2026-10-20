---
type: module
path: "@root/src/Pudu/Backend/Emit/Aggregate.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Aggregate Emission]
---
# Native Aggregate Emission

## Purpose and interface

Export ownedType, ownedKinds, retained, released, cType, memberRender,
tupleHelper, tupleNeed, aggregateTypes and aggregateSection.

A tuple is a `pudu_box`: a reference count and one cell per member. Each tuple
type gets helpers named after its mangled type (`pudu_tuple_make_T2_Int_Str_E`):

| Helper | Does |
| --- | --- |
| make | builds a box, retaining owned members |
| drop | releases one reference; the last one releases owned members and frees |
| show | `renderValue`: members rendered as inside an aggregate, joined by `pudu_text_join` |
| equal | Value's Eq, member by member: NaN unequal, integers by value |
| compare | compareValues, first differing member decides, -1/0/1 |

Needs are ordinary need names (`tuple_show:X`). `aggregateSection` closes
them over member helpers, always adds every drop (the frame engine releases
through them), writes helpers members first, and reports the runtime parts
they call. Unused helpers are never written, because C warns about unused
static functions.

Owned kinds number 1 for text and 2.. for tuple types in `aggregateTypes`
order; frame metadata and `pudu_drop_cell`/`pudu_retain_cell` use them.

## Grill Log

- **Q:** Why name helpers by a mangled type rather than an index? **A:** The
  value emitter can name a helper without threading a type table through
  emission state, and names are deterministic.
- **Q:** Why a box per tuple rather than flattening members into slots? **A:**
  Tuples nest, cross calls in one cell, and sit inside other aggregates;
  records, sums and Option/Result will share the box.
- **Q:** Why does compare answer GT for NaN? **A:** compareValues does
  (Haskell `compare` on Double); the emitter then applies base's Ord defaults,
  see [[Backend Frame Values]].

## Referenced by

[[Backend Frame Runtime]] · [[Backend Frame Values]] · [[Native Tuple Delivery]] · [[src/_MOC]]
