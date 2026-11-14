---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Runtime/Host/Compress.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Host Compression]
---
# Native Host Compression

Export the family's runtime parts and their prerequisites.

Bounded conversion to and from the gzip wrapper and the bare compressed stream, through the system's zlib, as `Pudu.Eval.Compress` answers them.

## Resolved Grill Log

- Carry a compressor in the runtime text? No: the part includes the system's zlib header, and the toolchain links that library only for a program whose source includes it.
- Which stream settings? The library's own defaults under the interpreter: the widest window, memory level eight, the default strategy; the gzip wrapper adds sixteen to the window and the bare stream negates it.
- Does the caller's chunk size change the bytes? No: it sizes buffers only, so it is read and not used.
- A level outside zero to nine? Refused before any work.
- A negative output limit? Refused before any work.
- Output past the limit? Refused when the piece that crosses it is taken, in pieces of 32768 bytes.
- Bytes after the stream's end? Refused: one member is read and nothing may follow it.
- Input that ends early or is malformed? The interpreter's library words, with zlib's own detail in parentheses for a format error.

## Referenced by

[[Native Host Runtime]] · [[Native Host Services]] · [[Native Toolchain]]
