---
type: module
path: "@root/lib/Std/Hex.pudu"
fidelity: Active
tags: [module, stdlib, hex, base16, codec, binary, low-level]
aliases: [Std Hex]
---
# Std Hex

## Purpose

Provide a low-level, high-throughput Hexadecimal (Base16) encoder and decoder inspired by Haskell `base16-bytestring` (Hoogle / Hackage) and Java `java.util.HexFormat`.
Operates directly on 4-bit nibbles with branchless ASCII byte mapping, supporting lowercase/uppercase formatting, strict validation, prefix stripping (`0x`), and byte serialization.

## Interface

### Functions
- `encode(bytes: &Array[UInt8]) -> Str`: Encodes a byte sequence into a lowercase hexadecimal string.
- `encodeUpper(bytes: &Array[UInt8]) -> Str`: Encodes a byte sequence into an uppercase hexadecimal string.
- `decode(hexStr: Str) -> Option[Array[UInt8]]`: Decodes a hexadecimal string into bytes. Returns `None` if the input has an odd number of digits or contains invalid hex characters.
- `decodeWithPrefix(hexStr: Str) -> Option[Array[UInt8]]`: Decodes a hexadecimal string, automatically stripping an optional leading `0x` or `0X` prefix.
- `isValid(hexStr: Str) -> Bool`: Tests whether a string consists of an even number of valid hexadecimal characters.
- `byteToHex(b: UInt8) -> (UInt8, UInt8)`: Splits a byte into high and low ASCII hexadecimal character bytes.
- `nibbleToAscii(n: Int, upper: Bool) -> UInt8`: Converts a 4-bit nibble ($0 \dots 15$) into its ASCII byte code.
- `asciiToNibble(c: UInt8) -> Option[Int]`: Converts an ASCII byte code into its 4-bit numeric value ($0 \dots 15$), or `None` if non-hex.

## Algorithm and boundaries

1. **Nibble Extraction:**
   Each input byte $B$ splits into two 4-bit nibbles:
   $$\text{high} = (B \gg 4) \mathbin{\&} \text{0x0F}, \quad \text{low} = B \mathbin{\&} \text{0x0F}$$
2. **Branchless Nibble to ASCII:**
   For lowercase:
   $$\text{ASCII}(n) = \begin{cases} n + 48 & \text{if } n < 10 \text{ ('0'..'9')} \\ n + 87 & \text{if } n \ge 10 \text{ ('a'..'f')} \end{cases}$$
   For uppercase, $n \ge 10$ adds 55 ('A'..'F').
3. **Strict Validation:**
   Any non-hex character or odd length input fails immediately without partial decoding or allocation.

## Grill Log

- **Q:** Why support both uppercase and lowercase encoders?
  **A:** Lowercase hex is canonical for cryptographic hashes (SHA-256, MD5) and UUIDs; uppercase hex is standard in network protocols, memory addresses, and binary dumps. Having both built-in avoids secondary string case conversions.
- **Q:** How does `decodeWithPrefix` handle inputs with `0x`?
  **A:** If the string begins with `0x` or `0X`, those two prefix characters are skipped in $O(1)$ time without slicing or duplicating string buffers.

## Referenced by

[[src/Std/_MOC]] · [[Std Bytes]] · [[Std Crypto]] · [[architecture/STDLIB]]
