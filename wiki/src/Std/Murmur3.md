---
type: module
path: "@root/lib/Std/Murmur3.pudu"
fidelity: Active
tags: [module, stdlib, hash, murmur3, non-cryptographic, low-level, bitwise]
aliases: [Std Murmur3]
---
# Std Murmur3

## Purpose

Provide a hardware-oriented, non-cryptographic hash function implementing Austin Appleby's MurmurHash3 (32-bit `hash32` and 64-bit mix `fmix64`), inspired by Java Guava (`Hashing.murmur3_32`) and Haskell `Data.Digest.MurmurHash3` (Hoogle / Hackage).
Optimized for hash tables, partition routing, and Bloom filter seeding with excellent avalanche properties and high throughput.

## Interface

### Functions
- `hash32(bytes: &Array[UInt8], seed: UInt32) -> UInt32`: Computes the 32-bit MurmurHash3 digest over a byte sequence with an initial `seed`.
- `hash32Text(text: Str, seed: UInt32) -> UInt32`: Convenience helper computing `hash32` directly over UTF-8 string bytes.
- `hash32Int(value: Int, seed: UInt32) -> UInt32`: Computes the 32-bit MurmurHash3 digest directly from a 64-bit integer without byte-array allocations.
- `fmix32(h: UInt32) -> UInt32`: Finalization mix stage (avalanche) for 32-bit integers, ensuring every input bit affects every output bit with equal probability.
- `fmix64(k: UInt64) -> UInt64`: Finalization mix stage for 64-bit integers using 64-bit hardware multiplication and shifts.
- `rotL32(x: UInt32, r: Int) -> UInt32`: 32-bit bitwise left rotation in CPU registers.

## Algorithm and boundaries

1. **4-Byte Word Processing:**
   Consumes input in 4-byte little-endian chunks $k$:
   $$k_1 = k \times \text{0xcc9e2d51u32}$$
   $$k_1 = \text{rotL32}(k_1, 15)$$
   $$k_1 = k_1 \times \text{0x1b873593u32}$$
   $$h_1 = h_1 \oplus k_1$$
   $$h_1 = \text{rotL32}(h_1, 13)$$
   $$h_1 = h_1 \times 5 + \text{0xe6546b64u32}$$
2. **Tail Processing:**
   Remaining 1, 2, or 3 trailing bytes are mixed into $k_1$ with appropriate shifts and combined into $h_1$.
3. **Avalanche Finalization (`fmix32`):**
   $$h = h \oplus \text{len}$$
   $$h = h \oplus (h \gg 16); \quad h = h \times \text{0x85ebca6bu32}$$
   $$h = h \oplus (h \gg 13); \quad h = h \times \text{0xc2b2ae35u32}$$
   $$h = h \oplus (h \gg 16)$$

## Grill Log

- **Q:** Why MurmurHash3 over cryptographic hashes like SHA-256?
  **A:** Cryptographic hashes require complex padding, hundreds of mixing rounds, and high CPU cycles. MurmurHash3 processes data in a few machine instructions per word, making it orders of magnitude faster for hash tables, Bloom filters, and cache keys where cryptographic preimage resistance is unnecessary.
- **Q:** How are 32-bit wrapping multiplications handled?
  **A:** All arithmetic uses Pudu's wrapping operators `&+` and `&*` on `UInt32` words, matching CPU ALU behaviour without software trap handlers.

## Referenced by

[[src/Std/_MOC]] · [[Std BloomFilter]] · [[Std Bytes]] · [[architecture/STDLIB]]
