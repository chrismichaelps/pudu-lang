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
- `readI64(buf: &Buffer, offset: Int) -> Option[Int64]`: Little-endian signed 64-bit load.
- `writeI64(buf: &Buffer, offset: Int, value: Int64) -> Option[Buffer]`: Little-endian signed 64-bit store.
- `readF64(buf: &Buffer, offset: Int) -> Option[Float64]`: Little-endian IEEE-754 64-bit float load.
- `writeF64(buf: &Buffer, offset: Int, value: Float64) -> Option[Buffer]`: Little-endian IEEE-754 64-bit float store.
- `readU32(buf: &Buffer, offset: Int) -> Option[UInt32]`: Little-endian unsigned 32-bit load.
- `writeU32(buf: &Buffer, offset: Int, value: UInt32) -> Option[Buffer]`: Little-endian unsigned 32-bit store.
- `fill(buf: &Buffer, offset: Int, len: Int, byte: UInt8) -> Option[Buffer]`: Vectorized memset.
- `compare(a: &Buffer, aOff: Int, b: &Buffer, bOff: Int, len: Int) -> Option[Int]`: Vectorized memcmp (-1, 0, 1).
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
- **Q:** How are bulk fills and comparisons optimized? **A:** `fill` and `compare` dispatch directly to hardware-accelerated C `memset` and `memcmp` kernels over contiguous unboxed slices.

## Referenced by

[[src/Std/_MOC]] · [[Backend Representation Specialization]]
