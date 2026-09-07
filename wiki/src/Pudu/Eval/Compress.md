---
type: module
path: "@root/src/Pudu/Eval/Compress.hs"
fidelity: Active
tags: [module, runtime, compression]
aliases: [Eval Compress]
---
# Eval Compress

## Purpose and interface

compressGzip(Bytes, level, chunkSize) and decompressGzip(Bytes, outputLimit) return IO IoOutcome Bytes.
The zlib 0.7.1 incremental API handles DEFLATE and gzip checksums. Output chunks are collected once;
inflate stops before retaining bytes above the caller limit. Input is fed in 32 KiB chunks. Exactly one
gzip member is accepted, with trailing bytes rejected. Malformed input is a typed failure.

## Dependencies

Codec.Compression.Zlib.Internal, bytestring, Eval Io. Consumed by [[Eval Effect]].
API reference: https://hackage.haskell.org/package/zlib-0.7.1.0/docs/Codec-Compression-Zlib-Internal.html

## Grill Log

- Resolved: reuse zlib rather than implement Huffman decoding and LZ matching in Pudu.
- Resolved: enforce output limits during incremental decoding, never after full allocation.
- Resolved: reject extra members/trailing bytes so parsing cannot silently discard input.
- Resolved: propagate asynchronous exceptions; translate synchronous host failures only.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Std Compress Gzip]] · [[Pudu Cabal Manifest]]
