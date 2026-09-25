---
type: module
path: "@root/src/Pudu/Eval/Checksum.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
tags: [module, runtime, hashing]
aliases: [Eval Checksum]
---

# Eval Checksum

## Purpose

Runtime-speed checksums for [[Std Checksum]]: CRC-32 (IEEE, reflected `0xedb88320`), CRC-32C
(Castagnoli, `0x82f63b78`), CRC-64 (ECMA-182 reflected `0xc96c5795d7870f42`, as xz computes it),
and FNV-1a in 32 and 64 bits.

## Interface

- `data ChecksumKind = Crc32Ieee | Crc32Castagnoli | Crc64Ecma | Fnv1a32 | Fnv1a64`.
- `checksumKindOf :: Integer -> Maybe ChecksumKind` — codes 0–4, anything else `Nothing`.
- `checksumUpdate :: ChecksumKind -> Word64 -> ByteString -> Word64`.

## Algorithm

Each is a strict left fold over the bytes. A CRC's `previous` is its finished value: it is inverted
back into the register, folded eight reflected shift steps per byte, and inverted out, so chaining
two calls equals one call over both chunks and `0` is the checksum of no bytes. FNV-1a's state is
its value, so its `previous` is the offset basis for a fresh hash. 32-bit results occupy the low
bits of the `Word64`.

## Grill Log

- **Q:** Keep the checksum in Pudu? **A:** No. _Rationale:_ a megabyte took 6.6 s in the evaluator
  and 43 ms here; a transfer cannot wait on the former. _Rejected:_ the Pudu table loop in
  `Std.Compress.Gzip`, which took 11 s.
- **Q:** A lookup table? **A:** Not yet. _Rationale:_ the bitwise fold needs no array dependency and
  is already far from the bottleneck behind the evaluator's own call cost. _Rejected:_ adding a
  dependency for a constant factor nobody measured as needed.
- **Q:** Trust agreement with a second implementation here? **A:** No. _Rationale:_ vectors come
  from the published check values, not from this code; [[Uses Checksum All]] asserts them.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Eval Builtin]] · [[Std Checksum]]
