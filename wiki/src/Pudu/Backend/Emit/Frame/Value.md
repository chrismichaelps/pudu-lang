---
type: module
path: "@root/src/Pudu/Backend/Emit/Frame/Value.hs"
fidelity: Active
aliases: [Backend Frame Values]
---
# Backend Frame Values

## Word-map helper admission (#810)

The four word tags require a Map[K, UInt64] receiver, one identical map
argument and identical map result. Reject mismatches as a located FrameFault
before C compilation. Select the corresponding typed keyed helper root.
Resolved Grill Log: no signed narrowing or reinterpretation of another cell
kind; the type-specific helper is emitted only after exact carrier admission.

## Purpose and interface

Export frameValue, slotText and cellMember. Translate pure FrameValue operations
to C expressions over stable frame->slots, preserving canonical integer kind
descriptors and shared arithmetic/shift diagnostic sites. Return Either FrameFault
(EmitState, expression Text, runtime root Set). No source evaluation, allocation,
implicit conversion, compiler/frontend import or host exception.

## Contract and failures

The private cell union uses integer for CoreIntegerType and scalar for Bool/Unit.
Text/Never payloads fail as data. Checked arithmetic, remainder, divide, shifts,
wrapping, saturation and comparisons select the existing production helpers;
logical binary operations are rejected because they require basic blocks.
Descriptor failures are located FrameFault data. Operands are already snapshots.
Only emitted values select helper roots; caller closes dependencies transitively.

## Resolved Grill Log

- **Q:** Re-evaluate a source operand while rendering? **A:** No; only slot reads occur.
- **Q:** Narrow a deferred positive integer? **A:** No; reuse the exact carrier.
- **Q:** Guess an integer descriptor? **A:** No; reject missing canonical metadata.

## Dependencies and consumers

[[Core Frame IR]] · [[Backend Emit State]] · [[Backend Emit Support]] · [[Backend Frame Bodies]]

## Grill Log

- **Q:** How are tags and payloads read? **A:** `FrameIsVariant` compares the box's first cell with the variant index, `FramePayload` reads a cell after the tag, and `FrameVariantName` answers the held variant's name as text (#525).

## Closures and tuple ordering (#555)

Resolved Grill Log: closures use their lifted function's maker, captures read
cells after cell 0, and tuple ordering checks both operands are comparable,
failing with the evaluator's `cannot apply < to a tuple and a tuple`
otherwise.

## Arrays (#556)

Resolved Grill Log: literals pass their cells to the type's maker; `get` and
indexing fail with E7004 at their own sites; other methods call the type's
helpers or the runtime.

## Str methods with collection results (#559)

The new text methods are plain runtime calls named after their parts.

## Integer conversion (#560)

The source slot's kind and the target pick one of four fit tests and
conversions in [[Native Integer Conversion]]; narrow to narrow is the same
value, normalised.

## Maps and sets (#561)

Keyed operations call the receiver type's helpers (the result type's, for
building from an array); `isEmpty` reads the root's size directly.

## Char from a code (#562)

`FrameCharOfCode` is the code's magnitude as a `uint32_t`.

## Range values (#564)

`FrameRangeValue` calls `pudu_range_make`; range operations come from
[[Backend Emit Range]] with their sites.

## Bytes (#565)

Each byte operation is one runtime call named by [[Backend Emit Bytes]].

## Referenced by

[[src/_MOC]] · [[Native Execution Frames]]

## Wide frame bridge (#506)

Use wide cells for 128-bit kinds and typed helper names for operations and selected roots. Comparisons choose the left integer operand kind, because their result is Bool. Shift counts remain platform Int cells. Resolved Grill Log: do not prefix comparison helpers twice, narrow deferred boundaries, or change eager operand snapshots. [[Native Wide Frame Bridge]].

## Floating operations (#512)

`cellMember` answers `floating` for both widths. Literals are written as
`UINT64_C(0x...)`. Negation is `pudu_float_neg`; `+ - * /` call
`pudu_float_add/sub/mul/div(left, right, narrow)` with `narrow` 1 for
Float32; comparisons call `pudu_float_eq/ne/lt/le/gt/ge`. Integer-only
operators on a float slot are a frame fault, since lowering never produces
them.

Resolved Grill Log: one helper call per Pudu operation keeps the evaluator's
round-after-every-operation rule and blocks contraction across operations.

## Text operations (#515)

`cellMember` answers `text`. Reads retain; literals use static bytes with no
owner; concatenation, display and show return new references. Comparisons go
through `pudu_text_compare`, which orders by bytes like Data.Text.

## Text methods (#516)

`FrameTextMethod` calls the matching [[Native Text Methods]] helper. Counting
methods return a `pudu_int`, predicates an `int`, text methods a new
reference. drop, take and repeat receive their E7004 sites.

## Trim and case mapping (#517)

The three methods call `pudu_text_trim`, `pudu_text_to_upper` and `pudu_text_to_lower`.

## Char values (#518)

`cellMember` answers `character` (a `uint32_t`). Literals are the scalar in
hex, comparisons are plain C comparisons, `code` is `pudu_make(c, 0)`.
Display calls `pudu_char_text`, show calls `pudu_char_show`, and charAt calls
`pudu_text_char_at` with its E7004 site.

## Tuples (#521)

`cellMember` answers `box`. Reads of any owned slot go through `retained`.
Construction, indexing, show and equality call [[Native Aggregate Emission]]
helpers. Ordering follows base's Ord defaults over compareValues, which are
written with `<=`: `x < y` is `compare y x > 0`, `x <= y` is
`compare x y <= 0`, `x > y` is `compare x y > 0`, `x >= y` is
`compare y x <= 0`. With the total order of #522 these equal the obvious
forms, but they stay written as base defines them so native follows the
interpreter even if a member order is ever not antisymmetric again. Resolved
Grill Log: before #522 a NaN member made `<` and `>` both true, and the
swapped forms are what matched it.

## Records (#521)

`cellMember` now delegates to [[Native Aggregate Emission]]'s `cellName`.
Rendering, show and equality use `isAggregate`, so records take the tuple
paths.

## Output Results (#566)

Resolved Grill Log: FrameOutputError calls pudu_output_write with the stream/newline flags and saved text slot; it selects output_error. This frame value is an ordered host effect, not a pure arithmetic operation. See [[Native Output Results]].

## First-class output builtins (#569)

Resolved Grill Log: FrameRuntimeKind selects the operand aggregate name helper, for sums or callables, with unchanged saved-slot ownership.

## Zero values (#638)

FrameZero emits zeroValue of the value's type. Resolved Grill Log: the same
zero the emitter already uses for an absent return.

ArrayReplaceAt emits the replace helper with an E7004 "index out of range" site at its span. (#649)

## BigInt (#800)

Conversions classify each side as one word, two words or BigInt. Every value fits a BigInt; a BigInt fits a fixed kind by `big_fits_int` or `big_fits_wide`. A BigInt literal needs `big_from_limbs`; display uses `text_display_big`.

## Decimal (#802)

Decimal literals, methods, operators with division's two failure sites, negation and display. `decimalFunction` names each method's runtime function.

## Query contract (#814)

Validate each query carrier and arity before selecting helpers: predicates take one identical map argument and Bool result, count has no arguments and UInt128 result, members has no arguments and Array[UInt64] result with UInt64 key/payload. Reject every mismatch as FrameFault at the query span.

Resolved Grill Log: project existing checked semantics; no inference, fallback, unsafe cell reinterpretation or frame ABI change. Reuse granular runtime dependencies and existing numeric/array ownership kernels.
