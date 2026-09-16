---
type: module
path: "@root/lib/Std/Archive/Tar.pudu"
fidelity: Active
tags: [module, stdlib, archive, tar, ustar]
aliases: [Std Archive Tar]
---
# Std Archive Tar

## Purpose

Read, write, and extract POSIX USTAR (IEEE Std 1003.1) tape archive streams.
Provides canonical tarball serialization for packaging, distribution, and containerization.
Composes seamlessly with [[Std Compress Gzip]] to produce and unpack `.tar.gz` (`.tgz`) archives.

## Interface

### Types
- `TarType = File | Directory | Symlink`: Distinguishable file entry classifications.
- `TarEntry = { path: Str, mode: Int, size: Int, mtime: Int, typeFlag: TarType, linkName: Str, data: Bytes }`: A file or directory contained within an archive.
- `TarError = CorruptHeader | InvalidChecksum | UnexpectedEof | UnsupportedType`: Structured decoding failure conditions.

### Archive Construction
- `entry(path: Str, data: Bytes) -> TarEntry`: Convenience constructor for regular file entries with default permissions (0o644).
- `directory(path: Str) -> TarEntry`: Convenience constructor for directory entries with default permissions (0o755).
- `writeArchive(entries: Array[TarEntry]) -> Bytes`: Serializes an array of tar entries into a 512-byte aligned USTAR archive ending with two 512-byte zero blocks.

### Archive Parsing
- `readArchive(archive: &Bytes) -> Result[Array[TarEntry], TarError]`: Decodes all entries from a raw USTAR byte stream.
- `extractFile(entries: &Array[TarEntry], path: Str) -> Option[Bytes]`: Looks up regular file contents by exact relative path.

## Algorithm and boundaries

Tar streams operate over strict 512-byte block boundaries.
Header checksums are calculated by summing all unsigned byte values across the 512-byte header block with the 8 checksum bytes treated as ASCII spaces (`0x20`).
Octal numbers are formatted with leading zeros and null/space terminators, and decoded by reading ASCII digits `'0'..='7'`.
Payloads are zero-padded to 512-byte alignment.
Decoding terminates when encountering two consecutive 512-byte blocks of zeroes or the end of the byte stream.

## Grill Log

- **Q:** Why POSIX USTAR format over GNU or PAX formats?
  **A:** USTAR is universally supported by `tar(1)`, standard Unix utilities, Go/Rust/Java/Python tar libraries, and requires no arbitrary extended headers for standard file paths.
- **Q:** How is `Std.Archive.Tar` integrated with `Std.Compress.Gzip`?
  **A:** `Tar.writeArchive` emits pure `Bytes`, which is compressed by `Gzip.compress` to produce `.tar.gz`. Conversely, `Gzip.decompress` decompresses `.tar.gz` bytes directly into `Tar.readArchive`.

## Referenced by

[[src/Std/_MOC]] · [[Std Compress Gzip]] · [[architecture/STDLIB]]
