---
type: module
path: "@root/lib/Std/Uuid.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, uuid]
aliases: [Std Uuid]
---
# Std Uuid
## Purpose
Represent UUIDs as sixteen bytes and construct deterministic v4/v7 values from explicit inputs.
## Interface
Exports nil, byte/text conversion, parsing, version inspection, equality, seeded v4 generation,
and timestamped v7 generation.
## Governance and algorithm
Generation accepts a random generator and v7 accepts milliseconds, keeping randomness and time
outside the pure module; parsing validates length, separators, hex, version, and variant bits.
## Grill Log
- **Q:** Read clock and randomness internally? **A:** No. _Rationale:_ explicit inputs make tests
  reproducible and effects visible. _Rejected:_ storing canonical identifiers as text.
## Referenced by
[[src/Std/_MOC]] · [[Std Bytes]] · [[architecture/STDLIB]]
