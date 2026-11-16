---
type: module
path: "@root/lib/Std/Mobile/Control.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, mobile, native, ui]
aliases: [Std Mobile Control]
---

# Std Mobile Control

## Purpose and interface

Pure encoder of the value controls of [[Pudu Native]]: a slider, a stepper, segmented choices, a wheel, a date picker, a text area, a search field, a system symbol, a page control and a color well. Each control is one variant of `Control`. The module owns how a control is created and how a change to it is revised; [[Std Mobile View]] wraps a `Control` as one node and calls `build` and `revise` from its reconciler. Instructions are spelled by [[Std Mobile Stream]].

Exports:
- `type Bounds = { low: Int32, high: Int32, step: Int32 }`: the range and step of a slider or stepper.
- `type Moment = Day | Time | DayAndTime`: what a date picker picks. Mode codes 0, 1 and 2 in that order, from the const table `MOMENTS`.
- `type Control = Slider(UInt32, Int32, Bounds) | Stepper(UInt32, Int32, Bounds) | Segments(UInt32, Array[Str], UInt32) | Wheel(UInt32, Array[Str], UInt32) | Date(UInt32, Int64, Moment) | TextArea(UInt32, Str) | Search(UInt32, Str, Str) | Symbol(Str) | Pages(UInt32, UInt32, UInt32) | Well(UInt32, UInt32)`: one control. The first word of a variant is its tag, which its events report. `Slider` and `Stepper` carry tag, value and bounds. `Segments` and `Wheel` carry tag, labels and the selected index. `Date` carries tag, whole seconds since the epoch and what it picks. `TextArea` carries tag and text. `Search` carries tag, hint and text. `Symbol` carries a system symbol name and no tag. `Pages` carries tag, page count and current page. `Well` carries tag and a packed RGBA color, red in the high byte.
- `build(out: Array[UInt8], node: UInt32, control: &Control) -> Array[UInt8]`: writes the full creation of one node: CREATE, TAG, then the control's fields. Bounds are written before the value and options before the selection, so the platform clamps against the right range.
- `revise(out: Array[UInt8], node: UInt32, before: &Control, after: &Control) -> Option[Array[UInt8]]`: answers the instructions that turn `before` into `after` on the same node. Only changed fields are written. A changed bound or option list rewrites the value after it. Answers None when the variant or the tag differs, so the node is replaced.
- `bits(value: Int32) -> UInt32`: the two's complement bits of a signed value, as one host word.

## Invariants

- Kind codes come from the constants of [[Std Mobile Stream]]: SLIDER 12, STEPPER 13, SEGMENTS 14, WHEEL 15, DATE 16, TEXT_AREA 17, SEARCH 18, SYMBOL 19, PAGES 20 and WELL 21.
- Mode codes come from the const table `MOMENTS`. No mode is chosen by an if-ladder or a match.
- Every value is an exact integer. No floating-point value crosses the stream.
- Bounds precede the value and options precede the selection in every `build`, so the platform never shows a value against a stale range.
- `revise` writes only the fields that changed. An unchanged control answers an empty stream.
- A changed option list or bound that moves the value rewrites the value after it, so the platform clamps the value against the new range.

## Negative Logic

- No clamping in Pudu. The platform clamps the value and reports what it shows.
- No validation of symbol names. An unknown name shows nothing.
- No formatting of dates. The platform formats the seconds.
- No node id is allocated here. The caller passes the node.
- No replacement decision beyond `None`. [[Std Mobile View]] decides what a `None` means for the tree.

## Dependencies and consumers

Depends on [[Std Mobile Stream]] for the instruction and kind codes. Consumers: [[Std Mobile View]], whose `Control` wrapper calls `build` and `revise`; the host [[iOS Host Values]], which realizes each kind; the example [[Native Controls Example]]; and the fixture [[Uses Mobile Controls]].

## Resolved Grill Log

- **Q:** Floating-point slider values? **A:** No. Values are Int32 with bounds and a step; a program wanting fractions scales them. Exact values keep interpreted and native runs identical. Rejected: Float64 on the stream.
- **Q:** Who clamps? **A:** The platform; Pudu reports back what is shown. Rejected: duplicating clamping in Pudu.
- **Q:** Unknown symbol name? **A:** Shows nothing and is not a defect: availability depends on the OS version. Rejected: a stream defect that would crash a shipped app on an older OS.
- **Q:** Date as text? **A:** No. Whole seconds since the epoch, independent of time zone and locale; the platform formats it. Rejected: ISO strings on the stream.
- **Q:** Color as components? **A:** Packed RGBA in one word, red in the high byte, matching the theme's packed colors.
- **Q:** One wrapper case or ten View cases? **A:** One `Control` case; this module owns the controls' build and revision, and View stays under the line budget. Rejected: growing View past 500 lines.

## Referenced by

[[src/Std/_MOC]] · [[Std Mobile View]] · [[Std Mobile Stream]] · [[iOS Host Values]] · [[Native iOS Controls Delivery]]
