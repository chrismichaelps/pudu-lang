---
type: module
path: "@root/src/Pudu/Compiler/Frame/State.hs"
fidelity: Active
aliases: [Compiler Frame State]
grammar: "[[grammar/haskell]]"
---
# Compiler Frame State

## Purpose and interface

Own a pure Build state/either-fault monad using existing base/containers/text
only. Allocate labels and typed slots monotonically, rename original Core local
IDs on binding, snapshot reads through new slots, append reversed instructions
and finish each block with exactly one terminator. Track the optional current
block and scoped CoreLoopId destinations/result slots. Missing locals/targets,
duplicate bindings or closing/opening inconsistent blocks are FrameFault data.
Closed blocks cannot receive more instructions. Final slots/blocks are emitted
in identity order. No parser/checker/evaluator dependencies or IO.

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

## Floating slots (#512)

`freshSlot` accepts `CoreFloatType`; only text and Never stay unrepresented.

## Text slots (#515)

`freshSlot` accepts `CoreTextType`; only Never has no slot.
