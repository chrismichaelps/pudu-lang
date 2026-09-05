---
type: module
path: "@root/lib/Std/Text/Source.pudu"
fidelity: Active
subsystem: "[[architecture/STDLIB]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib]
aliases: [Std Source Buffer]
---

# Std Source Buffer

## Purpose, interface, and invariants

An immutable byte buffer paired with line-start offsets for compiler and diagnostic consumers.
`fromBytes` scans LF delimiters once; `fromText` explicitly encodes UTF-8 first. `position` returns
one-based line and byte-column coordinates for an absolute byte offset, including EOF. Byte columns
are not Unicode scalar or display columns. `line` returns a shared byte view without LF or a preceding
CR in a CRLF terminator. A standalone CR remains ordinary content. A final LF creates an empty final
line; an empty source has one empty line. `slice` rejects invalid ranges rather than clamping.

Binary search is over the existing persistent `Array` representation. The bootstrap's sequence
indexing means this is not advertised as constant-time random access or a measured throughput win.
The exported record must retain the starts built by its constructors; callers altering that index
must preserve sorted offsets, initial zero, and source bounds.

## Grill Log

- **Q:** Count Unicode columns while indexing every source? **A:** No; byte offsets are the native
  input coordinate, and presentation-specific scalar or display columns are a separate operation.
- **Q:** Decode arbitrary bytes implicitly? **A:** No; source buffers may contain malformed UTF-8
  for diagnostics. Only `fromText` performs a named encoding step.

## Dependencies and consumers

Uses built-in bytes, text, arrays, maps, and failure carriers. Intended for explicit import by
compiler and parser clients. No foreign calls, hidden IO, or host primitives are introduced.

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]] · [[architecture/FFI-SELF-HOSTING]]
