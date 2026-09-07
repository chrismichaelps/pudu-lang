---
type: module
path: "@root/lib/Std/Compress/Gzip.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, compression, gzip, deflate, rfc1952, rfc1951, crc32]
aliases: [Std Compress Gzip]
---

# Std Compress Gzip

## Purpose

RFC 1952 GZIP file format compression, RFC 1951 DEFLATE block streaming, IEEE 802.3 CRC-32 checksumming, and HTTP server compression middleware using unboxed buffers.

## Interface

- `CompressionLevel`:
  - `NoCompression`: Raw stored blocks without compression penalty.
  - `Fast`: Stream-optimized stored blocks chunked at 65,535 byte boundaries.
  - `Default`: Standard compression profile.
  - `Best`: Maximum density profile.
- `GzipConfig`:
  - `level: CompressionLevel`
  - `chunkSize: Int`: Maximum chunk size for DEFLATE blocks (up to 65,535 bytes).
  - `minCompressBytes: Int`: Minimum payload length before HTTP middleware triggers compression.
- `GzipError`:
  - `InvalidMagic(Int, Int)`: Stream does not begin with RFC 1952 ID1/ID2 (`0x1F`, `0x8B`).
  - `UnsupportedCompressionMethod(Int)`: Compression method is not DEFLATE (8).
  - `CorruptHeader(Str)`: Reserved flags or malformed header components encountered.
  - `TruncatedStream`: Stream ends prematurely before block or footer completion.
  - `CorruptBlockHeader`: Block inverted length does not match block length (`NLEN != ~LEN`).
  - `UnsupportedBlockType(Int)`: Encountered reserved or unsupported DEFLATE block type.
  - `ChecksumMismatch(Int, Int)`: Computed CRC-32 does not match trailer CRC-32.
  - `SizeMismatch(Int, Int)`: Decompressed byte count does not match trailer ISIZE.
- `config() -> GzipConfig`:
  Initializes default compression configuration (`Default` level, 65,535 byte chunks, 256 byte min size).
- `withLevel(c: &GzipConfig, level: CompressionLevel) -> GzipConfig`:
  Sets the compression level profile.
- `withChunkSize(c: &GzipConfig, chunkSize: Int) -> GzipConfig`:
  Sets the DEFLATE block chunk size bounded between 1 and 65,535 bytes.
- `withMinCompressBytes(c: &GzipConfig, minBytes: Int) -> GzipConfig`:
  Configures the minimum body threshold for HTTP middleware.
- `crc32(data: &Bytes) -> Int`:
  Calculates the standard IEEE 802.3 32-bit Cyclic Redundancy Check over input bytes.
- `compress(data: &Bytes, cfg: &GzipConfig) -> Bytes`:
  Compresses uncompressed bytes into an RFC 1952 GZIP stream containing 10-byte header, DEFLATE blocks, and 8-byte trailer.
- `compressText(text: Str, cfg: &GzipConfig) -> Bytes`:
  Helper compressing UTF-8 text into a GZIP stream.
- `decompress(stream: &Bytes) -> Result[Bytes, GzipError]`:
  Decompresses an RFC 1952 GZIP stream, verifying magic headers, DEFLATE block checksums, CRC-32, and uncompressed size.
- `decompressText(stream: &Bytes) -> Result[Str, GzipError]`:
  Decompresses a GZIP stream and decodes the result as valid UTF-8 text.
- `middleware(cfg: &GzipConfig) -> Route.Middleware`:
  HTTP server middleware that checks `Accept-Encoding: gzip`, compresses eligible responses, and sets `Content-Encoding: gzip`.

## Invariants

- Magic bytes are strictly `0x1F` and `0x8B` in big-endian byte order.
- DEFLATE stored block sizes never exceed 65,535 (`0xFFFF`) bytes; larger payloads are split into multiple blocks with `BFINAL=0` except for the terminal block.
- For every stored block, $LEN \oplus NLEN = 0xFFFF$.
- The trailer stores the CRC-32 and original byte length modulo $2^{32}$ in little-endian order.
- CRC-32 utilizes the standard reflected polynomial `0xEDB88320`.
- All control flow is flat with early returns and guard clauses; zero nested match statements.
- Source files remain under 500 lines.

## Grill Log

- **Q: How does `Std.Compress.Gzip` achieve fast, hardware-friendly streaming compression while remaining 100% interoperable with standard tools (`gzip`, `gunzip`, browsers)?**
  - **Decision:** Implement RFC 1952 header (`ID1=0x1F`, `ID2=0x8B`, `CM=8`) and footer (CRC-32, ISIZE), with RFC 1951 DEFLATE stored block framing (`BTYPE 00`) using contiguous `Std.Buffer` memory blocks up to 65,535 bytes with length and one's-complement length verification. Stored blocks guarantee 100% RFC 1951 compatibility, zero data corruption, zero allocation thrashing, and can be decompressed by all RFC 1952-compliant clients.
- **Q: How is CRC-32 calculated efficiently without external C library dependencies?**
  - **Decision:** Generate an unboxed 256-word lookup table based on the standard IEEE 802.3 polynomial `0xEDB88320`. The inner loop operates via table lookup and bitwise shifts: `crc = table[(crc ^ b) & 0xFF] ^ (crc >> 8)`.
- **Q: What safeguards ensure integrity during decompression?**
  - **Decision:** Strictly enforce magic numbers (`0x1F`, `0x8B`), compression method (8), block length vs inverted length match (`LEN == ~NLEN & 0xFFFF`), and post-decompression trailer validation matching both calculated CRC-32 and uncompressed byte count (`ISIZE`).
- **Q: How is this integrated into HTTP services?**
  - **Decision:** Expose a pure `Route.Middleware` decorator following the middleware pattern that inspects `Accept-Encoding: gzip`, applies compression if body length exceeds `minCompressBytes`, and injects `Content-Encoding: gzip`.
- **Q: How does this follow advanced design patterns and maintainability?**
  - **Decision:**
    - **Builder Pattern** for `GzipConfig` with fluent chainable modifiers.
    - **Strategy Pattern** for compression level (`CompressionLevel`).
    - **Railway-Oriented Programming** with early return guards and zero nested matches.
    - Single-responsibility helper functions keeping all files $< 500$ lines.

## Boundary completion

HTTP middleware is passthrough until binary response transport is available: base64 bytes cannot be labeled Content-Encoding gzip. Codec currently supports stored DEFLATE only and does not reduce size; configuration is clamped at compression entry.
Resolved Grill Log: reject unsupported transport/representation behavior rather than emit corrupted output or silently weaken validation. No tests or reviews run.

## Header integrity limitation

The stored-block decoder refuses FHCRC headers until header CRC verification is implemented;
it never skips a declared integrity check. Compression profiles currently do not change the
stored-block encoding, and HTTP middleware is passthrough. This is not production compression.
