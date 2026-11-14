---
type: module
path: "@root/src/Pudu/Backend/Emit/Frame/TextView.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Frame Text Views]
---
# Backend Frame Text Views

## Purpose and interface
Export frameTextView, receiving saved-slot rendering, EmitState and FrameValue.
Return Nothing for other operations; otherwise return Either FrameFault with
updated state, C expression and helper roots. Consume FrameTextMethod byte tags.
No source lowering, interpretation, allocation or source-name inference.

## Invariants and algorithm
A closed descriptor table gives each internal method its parameter/result
carriers and C helper. Require a Str receiver, exact arity, platform Int offsets,
Str needles, and the precise Bool/Int/UInt8/Char/Str result before reading slots.
Reject a mismatch at the FrameValue span. Render only already-saved operands.
Select one helper root and let dependency closure provide shared kernels.

## Resolved Grill Log
Use one bounded translator for the byte-view methods rather than grow the
large Value dispatcher. A slot-rendering callback keeps the dependency one-way;
Nothing means unrecognized, while Left means a recognized malformed operation.
Legacy scalar Str methods remain in Value. No cell-layout or frame ABI change.

## Referenced by
[[Backend Frame Values]] · [[Native Text Views]] · [[src/Pudu/Backend/_MOC]]
