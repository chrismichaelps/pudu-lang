---
type: architecture
tags: [architecture, native, frames, performance]
aliases: [Native Frame Slot Reuse]
---

# Native Frame Slot Reuse

Reuse storage for temporary values with disjoint lifetimes so native frame
size follows simultaneous demand. Logical values remain distinct throughout
[[Compiler Frame Lowering]]. [[Backend Frame Slots]] computes physical slots
before [[Backend Frame Program]] selects direct calls and emits C11.

## Storage contract

- A candidate belongs to one basic block and starts at a store that does
  not read that logical slot. A block can execute repeatedly. Its first
  store still initializes the slot for each execution.
- Preserve dedicated storage for parameters, terminator operands,
  foreign-call arguments and slots touched in multiple blocks.
- Values of the same exact Core type can share storage. Include both
  ends of each interval, so distinct operands and destinations of one
  instruction stay disjoint.
- An owned candidate must end with a move out to a distinct slot. Existing
  move emission empties the source. Reuse preserves release timing for
  both normal execution and exits after any instruction that can fail.
- Preserve logical source spans on rewritten references. Emit one
  descriptor per physical slot. Physical numbering follows the
  function's slot order and the block's execution intervals deterministically.
- Leave malformed or inconsistent slot inventories available to the
  existing emitter's validation.

## Acceptance

Test dead straight-line values, overlapping operands, loop re-entry,
branch and resume destinations, foreign arguments, owned moves, and
exit-before-move cleanup. Compare C11 output results and diagnostics with
the interpreter and the existing native corpora. Measure the frame
descriptor and C source size for the signed-width pressure fixture.

After compaction, measure repeated output emission separately before
sharing its hot C sequences. Current measurement on the navigation
integration compiler was 6,394 frame slots, 4,131 owned slots and
1,429,513 C bytes for the 483-line signed Int8 matrix. The native result
matched the fixture's expected output. This measures build pressure.
Display cadence and frame deadlines require separate device evidence.

## Resolved Grill Log

- **Q:** Reuse a dead owned cell before it is explicitly emptied? **A:** Keep
  its physical slot. A final read says nothing about release timing.
- **Q:** Use numeric tags alone to classify a slot? **A:** Read its uses
  and definitions. Compiler temporaries and user locals follow the same
  storage proof.
- **Q:** Put the optimization in Core lowering? **A:** Keep logical storage
  stable through lowering. Compact the final frame before C generation so
  direct and resumable bodies agree on the same layout.

## Referenced by

[[architecture/_MOC]] · [[Native Execution Frames]] · [[Native Frame Slot Reuse Delivery]]
