---
type: module
path: "@root/src/Pudu/Backend/Emit/Aggregate.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Aggregate Emission]
---
# Native Aggregate Emission

## Retained positional constructors

Resolved Grill Log. A retained constructor renders and reports its
variant label. Its canonical identity governs equality and ordering
among constructor keys. It is an ordered empty positional sum value
even when stored in a callable slot. [[Core Closure Identities]]

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

## Generic records (#552)

Resolved Grill Log: a record with arguments mangles like a sum,
`R<n>_<key>_<args>_E`; one without keeps `R_<key>`, so existing output is
unchanged.

## Closures and ordering (#555)

Resolved Grill Log: function types are owned boxes with drop, show, equal,
compare and one maker per lifted function, switching on cell 0. A
`comparable` helper per aggregate mirrors `comparableValue`. Record and sum
members order through their own compare helpers: records field by field, sums
by variant name and then payload. Before this they compared by pointer.

## Arrays (#556)

Resolved Grill Log: array types get [[Backend Emit Array]]'s helpers; the cell
vocabulary moved to [[Backend Emit Cell]].

## Maps and sets (#561)

Helpers come from [[Backend Emit Keyed]]. A tuple or record compare helper now
marks both boxes used, since a type whose members are all functions reads
neither and C warned about it.

## Range values (#564)

Helpers come from [[Backend Emit Range]].

## Bytes (#565)

Helpers come from [[Backend Emit Bytes]].

## Text methods and Unit members (#846)

A closure that `isTextMethod` ([[Core Closure Identities]]) renders as
`<method toText>` and is named `text method`, as the interpreter's text method
value is; its equality still compares receivers. A record or tuple whose
members are all Unit renders without reading its box, so its show helper marks
the box used and the generated C stays free of warnings.

## Referenced by

[[Backend Frame Runtime]] · [[Backend Frame Values]] · [[Native Tuple Delivery]] · [[src/_MOC]]

## Records (#521)

Records share the box and the helpers; their mangled name is `R_Name`.
`show` writes `Name{x: a, y: b}` through `pudu_text_join`'s labels. Records
never need `compare`. Zero-member aggregates get `void` parameter lists and
no parts array.

## First-class output builtins (#569)

Resolved Grill Log: Callable show helpers use builtin versus function rendering from metadata; name helpers answer builtin/function for runtime diagnostics. Equality identity and non-orderability stay intact.

## Method closures (#644)

Show prints `<kind method name>` and the runtime kind is `kind method`, with
the interpreter's words (text, array, map, set, range, character, byte).
Equality compares sites, then a method closure's receivers. Use the
cross-layout helper when a site admits two capture layouts.
Resolved Grill Log. Each side's closure index determines its capture
layout. Seed the existing helper graph with the distinct capture pairs
and retain the direct member comparison for shared layouts.
[[Compiler Lower Method Value]] · [[Backend Cross Comparison]]

## Trait method closures (#646)

Method closures whose receiver is a record or sum render as `<fn name>`
with kind `function`; receiver equality applies only when a receiver was
captured.

## BigInt (#800)

`ownedKinds` gives BigInt code 2, after text; aggregates follow from 3.

## Decimal (#802)

`ownedKinds` gives Decimal code 3; aggregates follow from 4.

## Indexed stores (#840)

Stores contribute their held type to aggregate collection and take storeHelpers; a store method value's kind is `store`. Resolved Grill Log: helpers stay demand-selected.

## Tasks and dynamic values (#846)

A task closure shows and names itself by the task name it carries, not as a
function wrapper: show answers `<task name>` and its kind is `task`. Radix
weighting and equality are the function cases. A dynamic sum, recognized by
its `dynamic.` key, holds one value, so show renders that payload rather than
the variant name. Resolved Grill Log: a task is a value the writer can print;
the runtime text is the lifted function's own display name, and nothing
changes for ordinary closures.

## Every helper signature declared (#848)

A helper body may define more than one C function: the closure `equal` entry
defines `site` and then `equal`. Every line of a selected body that starts at
column zero with `static `, ends in ` {` and is not a table initializer
(` = {`) is a signature, and each one is declared ahead of every definition.

Resolved Grill Log: declare each signature rather than reorder the catalogue.
_Rationale:_ a sum or record whose type is seen before the function type it
holds calls that function type's `equal` from an earlier definition, and
recursive types make a members-first order impossible in general. _Rejected:_
splitting `site` into its own catalogue entry (every other multi-function body
would carry the same trap).

## Foreign handles (#853)

Handle types register the lifetime, rendering and comparison helpers from [[Backend Emit Foreign Handle]].

## Dynamic display (#956)

The dynamic display helper selects the held payload and uses its display
renderer. The show helper uses the held payload's quoted rendering.

### Resolved Grill Log

Text and characters keep their display behavior after widening. Aggregate
members and entry results keep the payload's show behavior.

## Foreign callable identity and dynamic integer order (#956)

Foreign function and callback-registration closures render by crossing
identity. Their runtime kind and comparability follow the recorded value
class. Dynamic variants holding integers compare exact magnitudes across
widths, including in tuples and ordered collections.

### Resolved Grill Log

A numeric payload pair takes its shared value order before nominal tag
ordering. Converting a mixed pair for comparison does not narrow either
operand and releases any temporary carrier.


## Ordering erased payloads and mixed sums (#956)

Dynamic boxes use the rank of the held value when two tags differ. Numeric
pairs still use numeric comparison. A sum's rank follows its active variant,
so positional and named variants of one type can rank differently.

### Resolved Grill Log

Compare shapes before nominal names. Use canonical owner order when distinct
record or sum implementations share a shape, and use the variant name when
comparing variants of one sum with the same shape.

## Comparisons across dynamic payload layouts (#956)

Resolved Grill Log: dynamic tags select held layouts. A pair of distinct
tags dispatches to [[Backend Cross Comparison]], which walks each side's
layout and compares their held values. Same-tag helpers retain the
usual dependency closure.

## Held kinds in dynamic diagnostics (#956)

Resolved Grill Log: a dynamic tag describes a layout. Diagnostics obtain
the held carrier's runtime label, following an ordinary sum's active
variant or a callable's actual kind.

## Exact Int layout

Resolved Grill Log: Exact Int has its own ownership discriminator so both integer layouts release through their matching cell.

Resolved Grill Log: a record laid out as a MultiMap also receives the add helper from [[Backend Emit Multi Map]].
