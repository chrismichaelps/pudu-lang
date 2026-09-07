---
type: module
path: "@root/lib/Std/Adler32.pudu"
fidelity: Active
tags: [module, stdlib, adler32, checksum, rfc1950, rolling-hash, low-level]
aliases: [Std Adler32]
---
# Std Adler32

## Purpose

Provide a high-performance Adler-32 checksum implementation conforming to RFC 1950 (ZLIB), inspired by Haskell `adler32` (Hoogle / Hackage) and Java `java.util.zip.Adler32`.
Processes byte streams with **5552-byte unrolled accumulation blocks** before taking modulo 65521, avoiding CPU integer division overhead in the inner loop. Includes $O(1)$ rolling hash capabilities for rsync-style chunking.

## Interface

### Functions
- `checksum(bytes: &Array[UInt8]) -> UInt32`: Computes the RFC 1950 Adler-32 checksum for a byte array.
- `checksumText(text: Str) -> UInt32`: Computes the Adler-32 checksum directly over UTF-8 text bytes.
- `update(adler: UInt32, bytes: &Array[UInt8]) -> UInt32`: Resumes an existing Adler-32 checksum with additional data.
- `roll(adler: UInt32, oldByte: UInt8, newByte: UInt8, length: Int) -> UInt32`: $O(1)$ rolling update that removes `oldByte` and adds `newByte` across a sliding window of size `length`.
- `combine(adler1: UInt32, adler2: UInt32, len2: Int) -> UInt32`: Combines two Adler-32 checksums of adjacent byte streams into the checksum of their concatenation.

## Algorithm and boundaries

1. **State Representation:**
   $$\text{Adler32} = (s_2 \ll 16) \mathbin{|} s_1$$
   Initial state is $s_1 = 1, s_2 = 0 \implies \text{Adler32} = 1$.
2. **5552-Byte Block Deferral:**
   $s_1$ and $s_2$ accumulate up to 5552 bytes ($N_{\max} = 5552$) without modulo 65521 ($65521 \approx 2^{16}$), because $s_2$ fits safely in a 32-bit unsigned integer ($5552 \times 255 \times 5553 / 2 < 2^{32}$).
   This defers hardware division instructions by a factor of 5552.
3. **Rolling Hash in $O(1)$:**
   $$\text{new } s_1 = (s_1 - \text{oldByte} + \text{newByte}) \pmod{65521}$$
   $$\text{new } s_2 = (s_2 - \text{length} \times \text{oldByte} + \text{new } s_1 - 1) \pmod{65521}$$

## Grill Log

- **Q:** Why use Adler-32 over CRC-32?
  **A:** Adler-32 is much faster to compute in software than CRC-32 (especially for small to medium blocks) because it uses simple additions rather than polynomial division tables, while still detecting 100% of single- and double-bit errors.
- **Q:** How is modulo 65521 optimized?
  **A:** By processing in 5552-byte chunks, modulo operations are completely eliminated from the byte-level inner loop.

## Referenced by

[[src/Std/_MOC]] · [[Std Compress Gzip]] · [[Std Bytes]] · [[architecture/STDLIB]]
