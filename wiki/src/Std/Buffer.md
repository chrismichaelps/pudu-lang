---
type: module
path: "@root/lib/Std/Buffer.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, buffer, performance, memory]
aliases: [Std Buffer]
---

# Std Buffer

## Purpose

Low-level contiguous byte buffer for unboxed scalar manipulation, memory-aligned data structures,
and fast binary packing.

## Interface

Exports:
- `Buffer`: Unboxed contiguous byte sequence backed by `Bytes`.
- `alloc(bytes: Int) -> Buffer`: Allocate zero-initialized buffer.
- `size(buf: &Buffer) -> Int`: Byte length.
- `readU64(buf: &Buffer, offset: Int) -> Option[UInt64]`: Little-endian unsigned 64-bit load.
- `writeU64(buf: &Buffer, offset: Int, value: UInt64) -> Option[Buffer]`: Little-endian unsigned 64-bit store.
- `scanU64(buf: &Buffer, offset: Int, count: Int, needle: UInt64) -> Option[Int]`: Linear search.
- `copy(src: &Buffer, srcOff: Int, dst: &Buffer, dstOff: Int, len: Int) -> Option[Buffer]`: Memory range copy.
- `toBytes(buf: &Buffer) -> Bytes`: View underlying raw bytes.
- `fromBytes(bytes: Bytes) -> Buffer`: Construct buffer from bytes.

## Governance

- All accesses are strictly bounds-checked against buffer capacity.
- Returns `Option` on out-of-bounds offsets to permit fast branching without unwinding.
- Immutable functional semantics: mutating stores return an updated `Buffer` value.

## Grill Log

- **Q:** Introduce an unsafe raw pointer type? **A:** No; memory safety and purity are preserved by bounds-checking every offset.
- **Q:** Little-endian or host-endian? **A:** Little-endian is explicitly mandated for cross-platform data interchange.

## Referenced by

[[src/Std/_MOC]] · [[Backend Representation Specialization]]
