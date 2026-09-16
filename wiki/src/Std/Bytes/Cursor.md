---
type: module
path: "@root/lib/Std/Bytes/Cursor.pudu"
fidelity: Active
subsystem: "[[architecture/STDLIB]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib]
aliases: [Std Byte Cursor]
---

# Std Byte Cursor

## Purpose, interface, and invariants

A persistent cursor over immutable bytes with absolute byte positions. `start`, `seek`, `remaining`,
`peek`, `take`, `skip`, and `u8` preserve the original buffer. `u16Be`, `u16Le`, `u32Be`, `u32Le`,
`u64Be`, and `u64Le` name byte order explicitly. Reads return `(value, nextCursor)` or a typed
`CursorError`; failure never changes the original cursor.

Bounds use subtraction after validating the position, avoiding overflow in `position + count`.
Negative counts and positions are rejected. Empty reads at EOF succeed. Byte views share their
source storage. Numeric reads assemble at most eight bytes without array conversion or text decoding.

## Grill Log

- **Q:** Advance a cursor on a short read? **A:** No; a failure has no successor cursor, and the
  immutable original can be reused for backtracking.
- **Q:** Check bounds after adding the requested count? **A:** No; compare against remaining
  capacity first, so an attacker-controlled count cannot wrap before validation.

## Dependencies and consumers

Uses built-in bytes, text, arrays, maps, and failure carriers. Intended for explicit import by
compiler and parser clients. No foreign calls, hidden IO, or host primitives are introduced.

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]] · [[architecture/FFI-SELF-HOSTING]]
