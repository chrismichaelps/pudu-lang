---
type: module
path: "@root/src/Pudu/Backend/Emit/Frame/Value.hs"
fidelity: Active
aliases: [Backend Frame Values]
---
# Backend Frame Values

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
