---
type: module
path: "@root/src/Pudu/Runtime/Buffer.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, runtime, performance, buffer, memory]
aliases: [Runtime Buffer Kernels]
---

# Runtime Buffer Kernels

## Purpose, interface and invariants

`Pudu.Runtime.Buffer` provides low-level, cache-conscious unboxed contiguous byte buffer operations,
enabling fast scalar storage, byte-level data packing, and vector scanning without boxed `Value` heap nodes.

Key operations:
- `allocateBuffer :: Int -> ByteString` allocates an $N$-byte zero-filled contiguous buffer.
- `readWord64LE :: ByteString -> Int -> Maybe Word64` reads a 64-bit little-endian word at byte offset.
- `writeWord64LE :: ByteString -> Int -> Word64 -> Maybe ByteString` returns an updated buffer with a 64-bit word written at offset.
- `readInt64LE :: ByteString -> Int -> Maybe Int64` reads a signed 64-bit integer.
- `writeInt64LE :: ByteString -> Int -> Int64 -> Maybe ByteString` writes a signed 64-bit integer.
- `readFloat64LE :: ByteString -> Int -> Maybe Double` reads an IEEE-754 64-bit double via hardware bit-casting.
- `writeFloat64LE :: ByteString -> Int -> Double -> Maybe ByteString` writes an IEEE-754 64-bit double via hardware bit-casting.
- `readWord32LE :: ByteString -> Int -> Maybe Word32` reads an unsigned 32-bit integer.
- `writeWord32LE :: ByteString -> Int -> Word32 -> Maybe ByteString` writes an unsigned 32-bit integer.
- `fillBytes :: ByteString -> Int -> Int -> Word8 -> Maybe ByteString` fills a slice with a byte (vectorized memset).
- `compareBytes :: ByteString -> Int -> ByteString -> Int -> Int -> Maybe Int` lexicographically compares two slices (vectorized memcmp).
- `copyBytes :: ByteString -> Int -> ByteString -> Int -> Int -> Maybe ByteString` copies a contiguous byte range between buffers.
- `scanWord64 :: ByteString -> Int -> Int -> Word64 -> Maybe Int` 4-word unrolled superscalar scan for a 64-bit needle.

All offset and length arguments are validated against buffer boundaries. Out-of-bounds accesses answer `Nothing` rather than faulting or reading arbitrary host memory.

## Grill Log

- **Q:** Expose raw unchecked memory pointers to pure code? **A:** No; all offsets are strictly bounded against the buffer's length, guaranteeing memory safety without segfaults.
- **Q:** Rely on architecture-specific alignment assumptions? **A:** No; little-endian byte-shift encoding ensures deterministic, portable scalar serialization across ARM64 and x86_64.
- **Q:** Allocate intermediate lists or boxed integers for scalar reads? **A:** No; unboxed `Word64` and `Int64` values are returned directly in host registers.
- **Q:** How are float reads and writes implemented? **A:** Using GHC.Float register bit-casts (`castDoubleToWord64`, `castWord64ToDouble`), mapping directly to hardware register moves without software decode overhead.
- **Q:** How are slice comparisons and bulk fills accelerated? **A:** Slices delegate to ByteString's underlying libc `memcmp` and `memset` implementations, achieving multi-gigabyte-per-second memory bandwidth speeds.

## Dependencies and consumers

Consumed by [[Eval Buffer]], [[Std Internal Buffer]], and columnar database storage.

## Referenced by

[[src/_MOC]] · [[Backend Representation Specialization]]
