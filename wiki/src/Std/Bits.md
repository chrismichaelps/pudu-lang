---
type: module
path: "@root/lib/Std/Bits.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, bits]
aliases: [Std Bits]
---

# Std Bits

## Purpose

Provide one generic contract for fixed-width integer bit operations and explicit helpers for masks,
rotations, shifts, population counts, and bit-field extraction.

## Interface

`Bits.width` reports the number of value bits in the concrete integer type. The exported `width`
helper and the remaining generic functions use that contract without asking callers to branch on a
specific integer type.

## Governance and algorithm

Width describes the type, not the current value. For example, `UInt8.width()` is `8` even when the
value is zero. Each compiler-wired integer implementation supplies its fixed width; the generated
documentation inherits this explanation from the trait member instead of repeating it on every
implementation.

## Negative logic

- Width never means the number of significant bits currently set.
- Signed integer widths include every stored bit; callers do not subtract the sign bit.
- Implementation entries do not duplicate the trait comment unless a concrete type needs a more
  specific explanation.

## Grill Log

- **Q:** Should `width` inspect the runtime value? **A:** No. _Rationale:_ masks, rotations, and
  bounded shifts need the storage width even for zero. _Rejected:_ significant-bit length.
- **Q:** Repeat the same comment on every primitive implementation? **A:** No. _Rationale:_ the law
  belongs to `Bits.width`, and documentation inheritance keeps all method pages consistent.
  _Rejected:_ copied comments that can drift.

Resolved Grill Log: the trait owns the fixed-width meaning; implementation pages inherit it unless
they provide a direct, more specific comment.

## Referenced by

[[src/Std/_MOC]] · [[Std BitSet]] · [[Std BitVector]]
