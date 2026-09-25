---
type: module
path: "@root/lib/Std/Checksum.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, hashing, bytes]
aliases: [Std Checksum]
---

# Std Checksum

## Purpose and interface

Checksums that catch accidental corruption in transfers, files, and storage, and a fast hash for
short keys — all over `Bytes`, and all streamable.

- `crc32(bytes) -> UInt32`, `crc32Update(previous, bytes) -> UInt32` — IEEE, as zip/gzip/PNG.
- `crc32c(bytes)`, `crc32cUpdate(previous, bytes)` — Castagnoli, as iSCSI/ext4.
- `crc64(bytes) -> UInt64`, `crc64Update(previous, bytes)` — ECMA-182 as xz computes it.
- `fnv1a32(bytes) -> UInt32`, `fnv1a64(bytes) -> UInt64`.
- `hex32(value) -> Str`, `hex64(value) -> Str` — fixed-width lowercase with leading zeros.

## Semantics

- `xUpdate(x(a), b) == x(a ++ b)`, and `xUpdate(0, a) == x(a)`: a stream is checked a chunk at a time.
- The arithmetic runs in [[Eval Checksum]] through the pure built-in `checksumOf`; the algorithm
  codes are private constants, so the functions here are the whole typed surface.
- Checksums detect accidents only. Tamper resistance is [[Std Crypto]]; keyed hashing for tables
  facing untrusted keys is [[Std SipHash]].

## Grill Log

- **Q:** One function taking an algorithm sum? **A:** A function per algorithm. _Rationale:_ the
  call names what it computes, and each result has its own width. _Rejected:_ a `Kind` parameter.
- **Q:** Answer `Int` as `Std.Compress.Gzip.crc32` did? **A:** No. _Rationale:_ an unsigned width is
  what the formats store; `Gzip.crc32` keeps its `Int` for its callers and delegates here.
- **Q:** Offer a chained FNV update? **A:** No. _Rationale:_ keys are hashed whole; the need is
  unproven and the offset basis would leak into callers.

## Dependencies and consumers

- Depends on the prelude `checksumOf` and `convertInteger`.
- Consumed by [[Std Compress Gzip]] and, through it, the zip reader; reached by [[Uses Checksum All]].

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]] · [[Eval Checksum]] · [[Uses Checksum All]]
