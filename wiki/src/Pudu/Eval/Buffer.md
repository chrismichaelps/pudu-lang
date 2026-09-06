---
type: module
path: "@root/src/Pudu/Eval/Buffer.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, runtime, performance, buffer]
aliases: [Eval Buffer]
---

# Eval Buffer

## Purpose, interface and invariants

`Pudu.Eval.Buffer` adapts [[Runtime Buffer Kernels]] for evaluation, providing pure wired-in built-in functions:
- `callBufferAlloc`: Allocates a zero-initialized buffer of length $N$. Reports E7004 for negative sizes.
- `callBufferReadU64`: Reads a 64-bit unsigned integer at offset; answers `Option[UInt64]`.
- `callBufferWriteU64`: Writes a 64-bit unsigned integer at offset; answers `Option[Bytes]`.
- `callBufferReadI64`: Reads a 64-bit signed integer at offset; answers `Option[Int64]`.
- `callBufferWriteI64`: Writes a 64-bit signed integer at offset; answers `Option[Bytes]`.
- `callBufferReadF64`: Reads an IEEE-754 64-bit float at offset; answers `Option[Float64]`.
- `callBufferWriteF64`: Writes an IEEE-754 64-bit float at offset; answers `Option[Bytes]`.
- `callBufferReadU32`: Reads a 32-bit unsigned integer at offset; answers `Option[UInt32]`.
- `callBufferWriteU32`: Writes a 32-bit unsigned integer at offset; answers `Option[Bytes]`.
- `callBufferFill`: Fills range with byte value; answers `Option[Bytes]`.
- `callBufferCompare`: Lexicographically compares two buffer ranges; answers `Option[Int]`.
- `callBufferScanU64`: Linear scan for a 64-bit word needle; answers `Option[Int]` with the index.
- `callBufferCopy`: Range copy between buffers; answers `Option[Bytes]`.
- `callBufferSize`: Returns buffer size in bytes.

Buffer values use the canonical `BytesValue` representation, providing seamless interoperability with
existing `Bytes` operations without conversion costs.

## Grill Log

- **Q:** Introduce a new heap constructor for buffers? **A:** No; `BytesValue` already wraps `ByteString`. Reusing it enables zero-cost conversions between raw buffers and byte slices.
- **Q:** Abort execution on out-of-bounds offsets? **A:** No; return `Option` so parsers, serializers, and search algorithms can branch on boundaries without unwinding.
- **Q:** Enforce endianness? **A:** Little-endian encoding is explicitly documented and enforced across all platforms.
- **Q:** How are signed and floating scalar widths handled? **A:** `Int64` uses `SignedKind 64`, `Float64` uses `Float64Width`, and `UInt32` uses `UnsignedKind 32`, preserving exact numerical semantics.

## Dependencies and consumers

- **Requires:** [[Runtime Buffer Kernels]], [[Eval Env]], [[Eval Value]].
- **Consumed by:** [[Eval Builtin]], [[Std Internal Buffer]].

## Referenced by

[[src/_MOC]] · [[Backend Representation Specialization]]
