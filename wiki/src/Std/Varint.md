---
type: module
path: "@root/lib/Std/Varint.pudu"
fidelity: Active
tags: [module, stdlib, varint, leb128, zigzag, codec, binary, serialization]
aliases: [Std Varint]
---
# Std Varint

## Purpose

Provide variable-length integer encoding and decoding (ULEB128 and signed ZigZag SLEB128) inspired by Haskell `Data.Binary.Varint` / `Data.LEB128` (Hoogle / Hackage), Google Protocol Buffers, and WebAssembly.
Packs 64-bit integers into 1 to 10 bytes depending on magnitude, reducing bandwidth and storage in binary wire protocols.

## Interface

### Types
- `VarintDecodeResult = { value: UInt64, bytesRead: Int }`: Unsigned decoded value and consumed byte count.
- `SignedVarintDecodeResult = { value: Int, bytesRead: Int }`: Signed decoded value and consumed byte count.

### Unsigned LEB128
- `encodeUleb128(value: UInt64) -> Array[UInt8]`: Encodes an unsigned 64-bit integer using little-endian 7-bit chunks with MSB continuation flag.
- `decodeUleb128(bytes: &Array[UInt8], offset: Int) -> Option[VarintDecodeResult]`: Decodes an unsigned 64-bit integer starting at `offset`. Returns `None` if the stream terminates prematurely or exceeds 10 bytes (malformed).
- `encodedLengthUleb128(value: UInt64) -> Int`: Computes the exact encoded size (1 to 10 bytes) in $O(1)$ time without buffer allocation.

### Signed ZigZag LEB128
- `encodeSleb128(value: Int) -> Array[UInt8]`: Encodes a signed 64-bit integer using ZigZag mapping so small negative numbers take 1–2 bytes.
- `decodeSleb128(bytes: &Array[UInt8], offset: Int) -> Option[SignedVarintDecodeResult]`: Decodes a signed 64-bit integer starting at `offset`.
- `toZigZag(value: Int) -> UInt64`: Maps signed integers to unsigned space: $0 \to 0, -1 \to 1, 1 \to 2, -2 \to 3, \dots$.
- `fromZigZag(value: UInt64) -> Int`: Inverse mapping from unsigned ZigZag representation to signed integer.

## Algorithm and boundaries

1. **ULEB128:**
   Repeatedly extracts the lowest 7 bits: `val & 0x7fu64`. If remaining bits exist (`val > 0x7fu64`), the continuation bit `0x80u8` is set:
   $$\text{byte} = (\text{val} \mathbin{\&} \text{0x7F}) \mathbin{|} \text{0x80}$$
   Shifts right by 7 bits each step until zero. Single-byte values ($0 \dots 127$) serialize in 1 byte.
2. **ZigZag Mapping:**
   Standard two's complement negative numbers have all upper bits set, which would otherwise force 10 bytes in unsigned LEB128. ZigZag mapping folds negative and positive numbers into alternating non-negative integers:
   $$\text{ZigZag}(n) = \begin{cases} 2n & \text{if } n \ge 0 \\ -2n - 1 & \text{if } n < 0 \end{cases}$$
   Thus $-1$ serializes in exactly 1 byte (`0x01u8`).

## Grill Log

- **Q:** Why cap decode at 10 bytes?
  **A:** A 64-bit integer can store at most $10 \times 7 = 70$ bits. Any varint sequence requiring $\ge 11$ bytes indicates malformed data or a malicious attempt to trigger integer overflow or infinite loops.
- **Q:** Why provide both unsigned and signed ZigZag codecs?
  **A:** ULEB128 is standard for unsigned counters, lengths, and indices (e.g. Wasm, DWARF). ZigZag SLEB128 is essential for signed data where small negative offsets are common (e.g. Protobuf, Avro, delta encoding).

## Referenced by

[[src/Std/_MOC]] · [[Std Bytes]] · [[architecture/STDLIB]]
