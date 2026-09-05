---
type: module
path: "@root/lib/Std/Db/Protocol.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, database, protocol]
aliases: [Std Db Protocol]
---
# Std Db Protocol
## Purpose
Encode and decode the PostgreSQL v3 wire messages used by [[Std Db]].
## Interface
Exports framed messages, startup/query/parse/bind/describe/execute/sync/terminate messages,
authentication payloads, row/field readers, and size inspection for streaming reads.
## Governance and algorithm
Lengths are checked before slicing; unknown messages remain representable; null values remain
distinct from empty text; parameter values travel apart from SQL source.
## Grill Log
- **Q:** Paste values into query text? **A:** No. _Rationale:_ values would become instructions and
  statement identity would vary by data. _Rejected:_ native-endian fields; treating truncation as EOF.
## Strict frame and row contract

`messageSize` returns the complete tagged message size or a typed protocol failure. It distinguishes
an incomplete five-byte header from an invalid signed length, and checks host integer conversion.
`bodyLength` remains an optional compatibility accessor and returns no value for malformed headers.
`readMessage` validates the length and tag encoding before slicing, preserving trailing messages.

Data rows distinguish SQL NULL (-1) from empty text, truncated fields, invalid negative lengths, and
invalid UTF-8. Only -1 yields `None`. Row descriptions require text format and both row readers
reject trailing bytes after the declared fields. Unsupported binary columns are a protocol failure.

### Resolved Grill Log

- **Q:** Turn a failed text decode into NULL? **A:** No; NULL has an explicit length sentinel.
- **Q:** Treat every parse error as a short frame? **A:** No; malformed headers cannot be repaired
  by reading more bytes, and must not drive unbounded buffering.
- **Q:** Accept unread bytes after the declared row? **A:** No; the payload is exactly one row.

## Referenced by
[[src/Std/_MOC]] · [[Std Db]] · [[Std Bytes]]
