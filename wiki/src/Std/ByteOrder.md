---
type: module
path: "@root/lib/Std/ByteOrder.pudu"
fidelity: Active
tags: [module, stdlib, byte-order, endianness, bswap, binary, network, low-level]
aliases: [Std ByteOrder]
---
# Std ByteOrder

## Purpose

Provide low-level, CPU-register byte-swapping and big-endian/little-endian binary serialization primitives, inspired by Haskell `byteorder` / `data-endian` (Hoogle / Hackage) and Java `java.nio.ByteOrder`.
Enables efficient binary protocol encoding (TCP/IP network byte order, disk formats, file codecs) with branchless bit manipulation across 16-bit, 32-bit, and 64-bit words.

## Interface

### Byte Swapping
- `bswap16(v: UInt16) -> UInt16`: Reverses the 2 bytes of a 16-bit unsigned word.
- `bswap32(v: UInt32) -> UInt32`: Reverses the 4 bytes of a 32-bit unsigned word.
- `bswap64(v: UInt64) -> UInt64`: Reverses the 8 bytes of a 64-bit unsigned word.

### Network Byte Order Helpers
- `htons(hostShort: UInt16) -> UInt16`: Converts 16-bit host integer to network byte order (Big-Endian).
- `ntohs(netShort: UInt16) -> UInt16`: Converts 16-bit network byte order integer to host byte order.
- `htonl(hostLong: UInt32) -> UInt32`: Converts 32-bit host integer to network byte order (Big-Endian).
- `ntohl(netLong: UInt32) -> UInt32`: Converts 32-bit network byte order integer to host byte order.

### Buffer Readers (Big-Endian & Little-Endian)
- `readU16BE(bytes: &Array[UInt8], offset: Int) -> Option[UInt16]`: Reads a 16-bit word in big-endian order.
- `readU16LE(bytes: &Array[UInt8], offset: Int) -> Option[UInt16]`: Reads a 16-bit word in little-endian order.
- `readU32BE(bytes: &Array[UInt8], offset: Int) -> Option[UInt32]`: Reads a 32-bit word in big-endian order.
- `readU32LE(bytes: &Array[UInt8], offset: Int) -> Option[UInt32]`: Reads a 32-bit word in little-endian order.
- `readU64BE(bytes: &Array[UInt8], offset: Int) -> Option[UInt64]`: Reads a 64-bit word in big-endian order.
- `readU64LE(bytes: &Array[UInt8], offset: Int) -> Option[UInt64]`: Reads a 64-bit word in little-endian order.

### Buffer Writers (Big-Endian & Little-Endian)
- `writeU16BE(v: UInt16) -> Array[UInt8]`: Serializes a 16-bit word into 2 big-endian bytes.
- `writeU16LE(v: UInt16) -> Array[UInt8]`: Serializes a 16-bit word into 2 little-endian bytes.
- `writeU32BE(v: UInt32) -> Array[UInt8]`: Serializes a 32-bit word into 4 big-endian bytes.
- `writeU32LE(v: UInt32) -> Array[UInt8]`: Serializes a 32-bit word into 4 little-endian bytes.
- `writeU64BE(v: UInt64) -> Array[UInt8]`: Serializes a 64-bit word into 8 big-endian bytes.
- `writeU64LE(v: UInt64) -> Array[UInt8]`: Serializes a 64-bit word into 8 little-endian bytes.

## Algorithm and boundaries

1. **Branchless Register Byte Swapping:**
   - 16-bit: $(v \ll 8) \mathbin{|} (v \gg 8)$.
   - 32-bit: $((v \mathbin{\&} \text{0x00FF00FF}) \ll 8) \mathbin{|} ((v \mathbin{\&} \text{0xFF00FF00}) \gg 8)$, followed by 16-bit rotation.
   - 64-bit: 8-byte pairwise byte reversal using masks `0x00FF00FF00FF00FF`, `0x0000FFFF0000FFFF`, and 32-bit shifts.
2. **Bounds Checking:**
   Reads return `None` if the requested word spans past `bytes.length()`, preventing buffer overreads.

## Grill Log

- **Q:** Why provide explicit `readU16BE` and `readU16LE` instead of an implicit host-endian default?
  **A:** Network packets (TCP, IP, DNS) and cross-platform file headers (PNG, ZIP, WebP) specify exact endianness in their wire formats. Explicit functions prevent silent endian bugs when code is compiled on different CPU architectures (x86/ARM vs PowerPC/MIPS).
- **Q:** What is the network byte order standard?
  **A:** In accordance with IETF RFC 1700, network byte order is big-endian. `htons` and `htonl` ensure words are serialized big-endian.

## Referenced by

[[src/Std/_MOC]] · [[Std Bytes]] · [[Std Net]] · [[architecture/STDLIB]]
