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

- **Q:** How does a canonical key become a C identifier? **A:** `mangleKey` writes each segment after its length, so `A.B_C` and `A_B.C` stay distinct; rendering uses the display name (#539).

- **Q:** How is a sum emitted? **A:** As a `pudu_box` whose first cell is the variant tag, then that variant's payload. Each concrete sum gets make, drop, show and equal helpers, written only when used, the same way tuples and records do (#525).

- **Q:** Why name helpers by a mangled type rather than an index? **A:** The
  value emitter can name a helper without threading a type table through
  emission state, and names are deterministic.
- **Q:** Why a box per tuple rather than flattening members into slots? **A:**
  Tuples nest, cross calls in one cell, and sit inside other aggregates;
  records, sums and Option/Result will share the box.
- **Q:** How do float members compare? **A:** Through `pudu_float_order`,
  compareValues' total order since #522: NaN equals NaN and sorts after every
  number, signed zeros equal. Before #522 the interpreter's NaN order
  contradicted itself; native matched it until the repair landed.

## Referenced by

[[Backend Frame Runtime]] · [[Backend Frame Values]] · [[Native Tuple Delivery]] · [[src/_MOC]]

## Records (#521)

Records share the box and the helpers; their mangled name is `R_Name`.
`show` writes `Name{x: a, y: b}` through `pudu_text_join`'s labels. Records
never need `compare`. Zero-member aggregates get `void` parameter lists and
no parts array.
