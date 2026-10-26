---
type: module
path: "@root/src/Pudu/Compiler/Frame.hs"
fidelity: Active
aliases: [Compiler Frame Lowering]
grammar: "[[grammar/haskell]]"
---
# Compiler Frame Lowering

## Purpose and interface

Export lowerFrames :: CoreModule -> Either FrameFault FrameModule. Validate
entry/function identities and deterministic per-function slot/block products.
Run structured Core through the expression/control lowerer and close a normal
fallthrough with a return. No user code executes and no interpreter fallback.
Internal malformed Core returns a FrameFault, never a host exception. Preserve
module/function order and canonical parameter/result types. This partition does
not wire the dispatcher or claim the frame-pressure regression is fixed.
Before returning a function, check that its entry and every jump, branch and
call continuation identify a closed block; unreachable labels need no block.

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

- **Q:** What does frame lowering pass on? **A:** The Core module's layouts, unchanged, to `frameModuleLayouts` (#525).

## Closures (#555)

Resolved Grill Log: closure information passes into the frame module;
`FrameCallValue` resumes like `FrameCall`.

## Referenced by

[[src/_MOC]] · [[Program Compiler Module Map]] · [[Native Frame Pressure Repair]]
