---
type: module
path: "@root/lib/Std/Memory.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, memory, allocator]
aliases: [Std Memory]
---

# Std Memory

## Purpose

Allocators of offsets: a `Resource` protocol, a monotonic `Arena`, and a fixed-block `Pool`, for programs that lay their own data out in an array or a `Std.Buffer`.

## Interface

- `Block = { offset, size }`; `alignUp(value, alignment) -> Option[Int]`.
- `Resource`: `allocate(&mut self, size, alignment) -> Option[Block]`, `release(&mut self, block) -> Bool`.
- `Arena`, `arena(capacity)`, `Monotonic`: `used`, `remaining`, `reset`.
- `Pool`, `pool(blockSize, blocks)`, `checkedPool(blockSize, blocks) -> Option[Pool]`, `Pooled`: `available`, `inUse`, `reset`.

## Invariants

- An arena's blocks never overlap and only move forward; `release` takes nothing back, and `reset` takes everything back.
- A pool's block `k` is at `k * blockSize`. Allocation and release use a bounded number of indexed bookkeeping operations. A released block is reused before a fresh one. Releasing an inactive coordinate, an unissued index or a block of the wrong size answers `false` and changes nothing. Equal coordinates from another pool or an earlier reset cannot be authenticated by this representation.
- Alignment must be a power of two. A pool serves an alignment only when it divides the block size, since block offsets are multiples of the block size.

## Grill Log

- **Q:** Allocate memory rather than offsets? **A:** Pudu values are owned and collected by the runtime; what a program lays out itself lives in storage it already owns. Handing out offsets is the part of an allocator that is the program's business. _Rejected:_ a second heap beside the runtime's.
- **Q:** Should an arena's `release` give back the last block? **A:** No; the reference monotonic resource ignores deallocation, and a release that sometimes works invites code that depends on the order of releases.
- **Q:** Detect a double release? **A:** Yes, with one flag per issued block. The flag records current coordinate activity and turns an immediate duplicate release into `false`; it is not an ownership or generation token.

## Dependencies and consumers

- **Requires:** nothing beyond the prelude.
- **Consumed by:** programs; `test-fixtures/stdlib/UsesMemory.pudu`.

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]]

## Completion contract (#527)

Keep caller-owned offset storage. alignUp computes padding without overflowing and answers None when the aligned result cannot fit Int. Add checkedPool for positive block size, nonnegative counts and representable capacity; the total pool constructor normalizes invalid capacity to an empty resource. Allocate bookkeeping only as fresh blocks are issued, and add pool reset. Block identifies coordinates, not resource identity or generation; do not promise rejection of a same-shaped foreign or stale Block. Preserve ordinary active-offset/size/double-release checks.

Resolved Grill Log: follow [[C++ Inspired View Coverage]]; add capabilities compatible with Pudu values and checked errors, without a new pointer ABI or implicit allocator state.
