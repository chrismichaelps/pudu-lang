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
- `Pool`, `pool(blockSize, blocks)`, `Pooled`: `available`, `inUse`.

## Invariants

- An arena's blocks never overlap and only move forward; `release` takes nothing back, and `reset` takes everything back.
- A pool's block `k` is at `k * blockSize`. Allocation and release are a constant amount of work. A released block is reused before a fresh one. Releasing a block twice, a block the pool did not hand out, or a block of the wrong size answers `false` and changes nothing.
- Alignment must be a power of two. A pool serves an alignment only when it divides the block size, since block offsets are multiples of the block size.

## Grill Log

- **Q:** Allocate memory rather than offsets? **A:** Pudu values are owned and collected by the runtime; what a program lays out itself lives in storage it already owns. Handing out offsets is the part of an allocator that is the program's business. _Rejected:_ a second heap beside the runtime's.
- **Q:** Should an arena's `release` give back the last block? **A:** No; the reference monotonic resource ignores deallocation, and a release that sometimes works invites code that depends on the order of releases.
- **Q:** Detect a double release? **A:** Yes, with one flag per block. The flag costs one byte of bookkeeping per block and turns a corrupting mistake into a `false`.

## Dependencies and consumers

- **Requires:** nothing beyond the prelude.
- **Consumed by:** programs; `test-fixtures/stdlib/UsesMemory.pudu`.

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]]
