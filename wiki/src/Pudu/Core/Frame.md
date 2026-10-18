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

## Referenced by

[[src/_MOC]] · [[Program Compiler Module Map]] · [[Native Frame Pressure Repair]]
