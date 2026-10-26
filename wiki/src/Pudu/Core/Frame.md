---
type: module
path: "@root/src/Pudu/Core/Frame.hs"
fidelity: Active
aliases: [Core Frame IR]
grammar: "[[grammar/haskell]]"
---
# Core Frame IR

## Purpose and interface

Define nominal FrameLabel and FrameSlotId, typed/source-located FrameSlot,
FrameModule/Function/Block, flat FrameInstruction and FrameTerminator data.
FrameValue contains literals, reads, unary operations and eager scalar binary
operations only. FrameScalarOperator has a hidden constructor with a total
projection that excludes logical And/Or; those require branches. Instructions
store values or print literal/scalar values. Terminators jump, branch, call
with a continuation and optional destination, return, or report operator failure.
Calls cannot occur inside a right-hand side. Slot types remain canonical Core
metadata; this module performs no inference, IO, allocation or target encoding.
Function parameters reference their allocated slots. Every operation/control
site retains the original Span; synthetic jumps/implicit returns may have no
source site. FrameFault carries optional span and reason as data.

## Invariants and failures

The contract in [[Native Execution Frames]] governs ordered effects, snapshots,
Never paths, call continuations and source provenance. The pure pass is separate
from allocation/failure policy and the future C dispatcher. No lower depth
limit, larger host stack, permanent refusal or interpreted fallback repairs
#499. The known integration regression remains red until dispatch is wired.

## Resolved Grill Log

- **Q:** May a call remain inside an emitted value expression? **A:** No; explicit suspension and a resume block are required.
- **Q:** Can a later argument re-read an earlier mutable operand? **A:** No; local reads produce snapshots before subsequent effects.
- **Q:** What does a Never path return? **A:** No payload and no continuation; subsequent instructions are not emitted.
- **Q:** Does pure control lowering choose memory-exhaustion behavior? **A:** No; that runtime boundary is resolved separately before allocator implementation.

## Dependencies and consumers

[[Pudu Core]] · [[Core Frame IR]] · [[Compiler Frame Lowering]] ·
[[Compiler Frame State]] · [[Compiler Frame Body]] · [[Native Execution Frames]]

## Grill Log

- **Q:** What do frames add for sums? **A:** `FrameConstruct` (variant index and payload), `FrameIsVariant`, `FramePayload` read only after the tag matched, `FrameVariantName`, the `FrameFailText` terminator, and the module's layouts (#525).

## Closures (#555)

Resolved Grill Log: `FrameClosure` and `FrameCapture` values, the
`FrameCallValue` terminator (closure first, then arguments), and the module's
closure information.

## Arrays and moves (#556)

Resolved Grill Log: `FrameArray`, `FrameArrayMethod`, `FrameIndex` and the
`FrameMove` instruction, which moves one slot's value into another and leaves
the source empty.

## Computed help (#558)

`FrameFailText` carries an optional slot of help text computed at run time.

## Integer conversion (#560)

`FrameIntegerFits` and `FrameIntegerConvert` carry the target kind and the
source slot.

## Referenced by

[[src/_MOC]] · [[Program Compiler Module Map]] · [[Native Frame Pressure Repair]]

## Floating cells (#512)

`FrameFloatLiteral !FloatWidth !Word64` stores an encoding into a slot whose
type is `CoreFloatType`. Unary negation and the existing binary scalar
operators apply to floating slots; the slot type picks the helper.

Resolved Grill Log: floating values are scalars in the frame ABI like
integers and Bool, so no new instruction or terminator is needed.

## Text values (#515)

`FrameTextLiteral !Text`, `FrameDisplay !FrameSlot` and `FrameShow !FrameSlot`
produce text. Concatenation and comparison use `FrameBinary` on text slots.
Every text-producing value is a fresh reference; a store owns it.

## Text methods (#516)

`FrameTextMethod !CoreTextMethodName !FrameSlot ![FrameSlot]` computes a
method from already-evaluated slots. A method that can fail carries its
failure sites in the emitted call, like checked arithmetic.

## Char values (#518)

`FrameCharLiteral !Char` and `FrameCharCode !FrameSlot` are the only new
shapes. Comparisons, display, show and charAt reuse `FrameBinary`,
`FrameDisplay`, `FrameShow` and `FrameTextMethod` on Char slots.

## Tuples (#521)

`FrameTuple ![FrameSlot]` builds a tuple from evaluated slots and
`FrameTupleIndex !Int !FrameSlot` reads one member. Comparisons and
rendering reuse `FrameBinary`, `FrameShow` and `FrameDisplay`.

## Aggregates (#521)

`FrameTuple` and `FrameTupleIndex` are renamed `FrameAggregate` and
`FrameMember`: tuples and records share one boxed layout, members in
declaration order.
