---
type: module
path: "@root/lib/Std/Compress/Gzip.pudu"
fidelity: Active
tags: [module, stdlib, compression, gzip]
aliases: [Std Compress Gzip]
---
# Std Compress Gzip

## Purpose

Compress bytes with zlib DEFLATE, decode bounded gzip payloads, and negotiate HTTP response compression.

## Interface

- `config()` returns Default level, 65535-byte output chunk preference and 256-byte HTTP threshold.
- `withLevel`, `withChunkSize`, `withMinCompressBytes` configure immutable settings.
- `NoCompression`, `Fast`, `Default`, `Best` select zlib levels 0, 1, 6 and 9.
- `compressChecked(data, config)` returns `Result[Bytes,GzipError]` for callers handling codec failure.
- `compress` and `compressText` retain Bytes results and panic on unexpected codec failure.
- `decompressWithin(stream, maxBytes)` decodes one member with an output budget; `decompress` uses 64 MiB.
- `decompressText` additionally requires valid UTF-8. `crc32` remains a public checksum utility.
- `middleware(config)` negotiates gzip and returns binary responses when compression reduces size.

## Algorithm and boundaries

[[Eval Compress]] owns zlib integration. Stored, fixed and dynamic Huffman blocks are decoded by zlib,
including gzip header and trailer integrity checks. Trailing data, including additional members,
is refused. The output limit is checked as chunks emerge, before appending them to retained output.
The public byte-returning APIs buffer the whole result; they are not network streaming APIs.
The runtime codec primitives are effects and cannot run in constant initializers.

HTTP negotiation matches exact gzip or wildcard tokens and parses q values in thousandths. An explicit
gzip refusal overrides a wildcard. Vary is retained even when an eligible identity response is selected.
Compression skips ranges, existing Content-Encoding, bodyless statuses, CONNECT, event streams,
no-transform, Authorization, Cookie, Set-Cookie and private/no-store responses. This policy is conservative;
applications must also keep reflected secrets out of compressed public content. No general side-channel
immunity is claimed. The middleware does not implement a universal 406 negotiation policy for identity.

Encoded bytes live in Response.binaryBody. Stale length, transfer framing, ETag, digest and range
metadata are removed, then gzip encoding and the actual compressed length are added. Header-only guards
preserve the binary override. Codec failure returns the original response with Vary rather than mislabeled bytes.

## Grill Log

- Resolved: delegate DEFLATE to zlib rather than ship a custom Huffman/LZ codec.
- Resolved: native output limits apply during decoding; untrusted ISIZE does not select allocation.
- Resolved: actual gzip bytes cross HTTP; base64 is never sent as gzip.
- Resolved: preserve text response constructors while adding an explicit optional binary payload.
- Resolved: skip confidential or nontransformable responses; application policy still owns secret classification.

## Usage

```pudu
let config = Gzip.withLevel(&Gzip.config(), Gzip.Fast)
let encoded = Gzip.compressChecked(&payload, &config) ?
let decoded = Gzip.decompressWithin(&encoded, 8388608) ?
let service = Server.using(&Server.server(&routes), Gzip.middleware(&config))
```

For direct binary output use `Reply.bytes(200, "application/octet-stream", &payload)`.
Public responses eligible for compression must not carry private/no-store cache policy.
No builds, tests, reviews or measurements ran for this implementation; readiness is unproven.

## Referenced by

[[src/Std/_MOC]] · [[Eval Compress]] · [[Std Http]] · [[Std Http Server]]

Existing fixture migration: [[src/test-fixtures/stdlib/UsesGzip]]. No execution evidence is claimed.
