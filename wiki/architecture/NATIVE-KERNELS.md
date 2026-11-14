---
type: architecture
tags: [architecture, backend, native, kernels]
aliases: [Native Builtin Kernels]
---
# Native Builtin Kernels

The pure builtin kernels are native: fixed-width buffer access, the column
kernels, sort indices, the flat table behind `Std.FlatMap`, digests and keyed
digests, `deriveKey`, `checksumOf`, sealing, the RSA and P-256 signature
checks, the audio byte generators and the JSON, XML and CSV codecs. Each is a
first-class value as well as a direct call.

| Family | Native surface |
| --- | --- |
| Buffers | `bufferAlloc`, the fixed-width reads and writes, `bufferFill`, `bufferCompare`, `bufferCopy`, `bufferScanU64`, `bufferSize` |
| Columns | sums, extremes, threshold filters, projection, addition, bitmaps, sort indices, binary search, gather |
| Flat table | `swissTableEmpty`, `swissTableLookup`, `swissTableInsert`, `swissTableDelete`, `swissTableEntries`, `swissTableSize` |
| Digests | SHA-2, SHA-3, BLAKE2b, HMAC over SHA-256 and SHA-512, PBKDF2 |
| Checks | `constantTimeEqual`, `checksumOf`, `sealBytes`, `openSealedBytes`, `verifyRsaSha256`, `verifyEcdsaSha256` |
| Audio | `audioToneBytes`, `audioRampBytes` |
| Codecs | `jsonDecode`, `jsonEncode`, `xmlDecode`, `csvRecords` |

## Contract

Lowering reads every operand once, in source order, into held locals and
stops on Never before later operands run. Guards run in the interpreter's
order with its codes, messages and spans. The table of kernel names is closed
([[Core Kernel Operations]]), so emission cannot reach a kernel it has no
runtime function for. Layout integers (variant indexes, field positions,
modes) are fixed by the checked `Std.Json`, `Std.Xml` and `Std.Csv` shapes
and refuse when a program's type does not have them.

The Option results are built in Core from a test and a read; the runtime
returns a box, an index or a presence flag and never names a sum layout
except where a codec builds a whole tree.

## Evidence

- Digests, keyed digests, derived keys and sealing agree with Python `hashlib`
  and RFC 8439 vectors; checksums agree with `zlib` and the published
  CRC-32C, CRC-64 and FNV check values.
- RSA and ECDSA verdicts agree with OpenSSL signatures at 1024, 2048 and
  3072 bits and on P-256, including malformed and high-s signatures.
- Buffer, column, flat-table and codec programs match the interpreter byte for
  byte, refusals included, under the counted-allocation harness.
- Sort indices match the interpreter's list sort over 64 NaN-laden columns.

## Resolved Grill Log

Each kernel is written from the interpreter's own function, step by step,
rather than from a faster variant whose results differ on invalid inputs (the
point-at-or-above-the-prime and NaN cases). Layout integers come from checked
shapes, not from names. No kernel is claimed without its reference evidence.

## Referenced by

[[architecture/_MOC]] · [[Native Emission Coverage]] · [[Native Indexed Stores]]
