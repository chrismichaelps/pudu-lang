---
type: module
path: "@root/lib/Std/Mobile/Control.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, mobile, native, ui, controls]
aliases: [Std Mobile Control]
---

# Std Mobile Control

## Purpose and interface

Pure description of the value controls of a phone screen: slider, stepper, segmented control, wheel, date picker,
multi-line text, search field, symbol, page indicator and color well. [[Std Mobile View]] wraps one `Control` in its
`Control` variant; this module owns the words that describe one. It builds the instructions that create a control and
the instructions that change one, and it holds the normalization that makes every value the program sends one the host
can show. The module performs no I/O. Words are spelled by [[Std Mobile Stream]]; reports come back through
[[Std Mobile Events]].

Exports:
- `type Bounds = { low: Int32, high: Int32, step: Int32 }`: the range of a slider or stepper. Values are whole
  numbers; `step` is the distance between two selectable values.
- `type DateMode = Day | Time | DayAndTime`: the fields a date picker shows. Stream codes 0, 1 and 2.
- `type Control = Slider(Bounds, Int32, UInt32) | Stepper(Bounds, Int32, UInt32) | Segments(Array[Str], UInt32, UInt32) | Wheel(Array[Str], UInt32, UInt32) | Date(DateMode, Int64, UInt32) | TextArea(Str, UInt32) | Search(Str, Str, UInt32) | Symbol(Str) | Pages(UInt32, UInt32, UInt32) | Well(UInt32, UInt32)`.
  The last field of every variant but `Symbol` is the tag its events report. Per variant:
  - `Slider` and `Stepper`: bounds, value, tag.
  - `Segments` and `Wheel`: option labels, selected index, tag.
  - `Date`: mode, seconds since the Unix epoch, tag.
  - `TextArea`: text, tag.
  - `Search`: hint, text, tag.
  - `Symbol`: system symbol name. It has no tag and reports nothing.
  - `Pages`: page count, current page, tag.
  - `Well`: RGBA color with red in the high byte, tag.
- `built(out: Array[UInt8], id: UInt32, control: &Control) -> Array[UInt8]`: appends CREATE for node `id` and every
  instruction that shows the control's normalized state.
- `changed(out: Array[UInt8], id: UInt32, before: &Control, after: &Control) -> Option[Array[UInt8]]`: appends only the
  instructions for what differs between the two normalized states. Answers `None`, with nothing appended, when the
  variants differ or the tags differ; the caller then replaces the node.

## Normalization

Every value is normalized before it is compared or written:

- A step below 1 reads as 1.
- A high below low reads as low.
- A value is clamped into `[low, high]` and snapped down to a multiple of the step from low.
- A slider or stepper value is clamped and snapped, then written as the value itself, one signed word. The host converts it to its own step index.
- A selected index past the last option reads as the last option.
- An empty option list writes neither OPTIONS nor VALUE.
- A page past the count reads as the last page.

Comparison happens after normalization. A raw change that normalizes to the same state writes nothing: with low 0 and
step 2, a value changing from 6 to 7 snaps to 6 and writes no instruction.

## Stream

`built` writes the following, in this order. BOUNDS, OPTIONS and COUNT always precede VALUE.

| Variant | Instructions written |
| --- | --- |
| Slider | CREATE 12, BOUNDS 41, TAG 5, VALUE 29 (normalized value) |
| Stepper | CREATE 13, BOUNDS 41, TAG 5, VALUE 29 (normalized value) |
| Segments | CREATE 14, OPTIONS 42, TAG 5, VALUE 29 (selected index); OPTIONS and VALUE omitted when empty |
| Wheel | CREATE 15, OPTIONS 42, TAG 5, VALUE 29 (selected index); OPTIONS and VALUE omitted when empty |
| Date | CREATE 16, MOMENT 44 (mode, seconds), TAG 5 |
| TextArea | CREATE 17, TEXT 2, TAG 5 |
| Search | CREATE 18, HINT 8, TEXT 2, TAG 5 |
| Symbol | CREATE 19, TEXT 2 (symbol name) |
| Pages | CREATE 20, COUNT 43, TAG 5, VALUE 29 (current page) |
| Well | CREATE 21, TAG 5, VALUE 29 (RGBA) |

`changed` writes the following for a pair with the same variant and tag. Nothing is written when no listed field differs.

| Variant | Instructions written |
| --- | --- |
| Slider, Stepper | BOUNDS when the normalized bounds differ; VALUE when the value differs or the bounds differ |
| Segments, Wheel | OPTIONS when the list differs; VALUE when the index differs or the list differs |
| Date | MOMENT when the mode or the seconds differ |
| TextArea | TEXT when the text differs |
| Search | HINT when the hint differs; TEXT when the text differs |
| Symbol | TEXT when the name differs |
| Pages | COUNT when the count differs; VALUE when the current page differs or the count differs |
| Well | VALUE when the RGBA value differs |

Reports the host sends back, decoded by [[Std Mobile Events]]: Slider, Stepper, Segments, Wheel and Pages report
VALUED; Well reports COLORED; Date reports DATED; TextArea and Search report CHANGED. Symbol reports nothing.

## Invariants

- Pure: the module declares no foreign function and allocates no node ids. The caller passes `id`.
- Every value written is the normalized value. The host never receives a value the module did not normalize.
- Slider and stepper values lie on the step grid from low after normalization. The host converts each value to its index and reports `low + index * step`.
- Integers are written exactly: Int32 as one two's complement word, Int64 as two words, high then low.
- A change to bounds or to an option list resends the value, because the same index then names another value.
- `changed` never writes CREATE and never writes a node replacement; a variant or tag change is `None`.
- Each function appends to the stream it is given and returns the extended stream.

## Negative Logic

- No node replacement. A variant or tag change is reported as `None`, never as a partial update.
- No validation at the host boundary. Bounds and indexes are normalized here; the host refuses only what this module
  cannot produce, as [[pudu-ios-values]] lists.
- No event decoding and no tag interpretation. The module writes tags; it never reads one back.
- No I/O and no platform call.
- No report for a symbol. A symbol has no tag, so no event names it.

## Dependencies and consumers

Depends on [[Std Mobile Stream]] for the instruction spellings CREATE, TEXT, HINT, TAG, BOUNDS, OPTIONS, COUNT, MOMENT
and VALUE. Consumers: [[Std Mobile View]], whose `Control` variant calls `built` and `changed` for its node. The host
side is [[pudu-ios-kinds]], which dispatches kinds 12 to 21, and [[pudu-ios-values]], which realizes them.

Kept as a separate module because [[Std Mobile View]] stays under its file limit, and one wrapper case in the view
reconciles all ten controls. The control set changes independently of the reconciler.

## Resolved Grill Log

- **Q:** Why are values exact integers on the stream? **A:** The stream carries the snapped value itself, a whole number on
  the step grid, so the host's conversion to its index is exact and the report back is `low + index * step`. _Rejected:_ floating values on the stream, which the
  platform would round differently per control.
- **Q:** Why normalize in the program and not in the host? **A:** The host refuses what it cannot show, so a refusal
  must mean a defect. A program-side clamp keeps every value the program sends valid, and the reconciler compares the
  state the user sees. _Rejected:_ clamping in the host, which hides the program's value from the reconciler.
- **Q:** Why does a changed range resend the value? **A:** The index is relative to the range. A new low or step makes
  the old index name another value, so the value must follow the range.
- **Q:** Why does an empty option list write no VALUE? **A:** No index is valid for an empty list. VALUE past the
  option count is refused by the host, so the module omits it.
- **Q:** Why is a page past the count read as the last page? **A:** A count shrink must not leave the indicator on a
  page that no longer exists, and the user sees the last page the host can show.
- **Q:** Why does BOUNDS, OPTIONS and COUNT precede VALUE? **A:** The host applies a value against the range, options
  or page count it already holds. The value written last is the one the platform shows.
- **Q:** Why a separate module rather than more View variants? **A:** [[Std Mobile View]] stays under its file limit,
  and one wrapper case reconciles all ten controls, so the reconciler does not grow with each control.

## Referenced by

[[src/Std/_MOC]] · [[Std Mobile View]] · [[Std Mobile Stream]] · [[Std Mobile Events]] · [[pudu-ios-kinds]] · [[pudu-ios-values]] · [[Native Value Controls Delivery]]
