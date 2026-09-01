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
## Referenced by
[[src/Std/_MOC]] · [[Std Db]] · [[Std Bytes]]
