---
type: module
path: "@root/lib/Std/Bytes.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, bytes]
aliases: [Std Bytes]
---
# Std Bytes
## Purpose
Represent byte sequences independently from text and provide binary, hexadecimal, and base64 work.
## Interface
Exports construction, slicing/search, binary integer get/put, UTF-8 conversion, hex/base64 codecs,
and explicit copying operations.
## Governance and algorithm
Short input is a typed `BytesError`; byte order is named on every numeric operation; slicing uses the
runtime byte representation and whole-input encoders build chunks before joining.
## Grill Log
- **Q:** Reuse `Array[UInt8]` as the public type? **A:** No. _Rationale:_ bytes need compact storage,
  slice semantics, and a text boundary that an ordinary array does not promise. _Rejected:_ text as
  binary storage; implicit decoding.
## Referenced by
[[src/Std/_MOC]] · [[Eval Bytes]] · [[architecture/STDLIB]]
