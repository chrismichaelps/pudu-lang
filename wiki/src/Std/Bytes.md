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
runtime byte representation and whole-input encoders build chunks before joining. `join` joins
neighbours in pairs, level by level, and `repeat` doubles its running copy, so both are whole-run
copies rather than a value per octet.

The hexadecimal and base64 encoders gather one piece per byte or per three-byte group — hex pairs
come from a 256-entry table — and join them once. The decoders walk the text's characters in order,
because reaching a character by position walks the UTF-8 text before it. Both directions are linear:
at 120,000 bytes hex encoding takes about 0.42 s and base64 decoding about 0.98 s at -O2, where
per-byte appending and positional reads took 2.3 s and 2.0 s and grew with the square of the input.
A bad hex digit is reported at the start of its pair and a bad base64 digit at its own position;
trailing base64 padding is counted once from the end.
## Grill Log
- **Q:** Reuse `Array[UInt8]` as the public type? **A:** No. _Rationale:_ bytes need compact storage,
  slice semantics, and a text boundary that an ordinary array does not promise. _Rejected:_ text as
  binary storage; implicit decoding.
- **Q:** Keep codecs that append to text and read digits by position? **A:** No. _Rationale:_ both
  cost time growing with the square of the input, and attachments and uploads are large.
  _Accepted:_ gathered pieces joined once and in-order character walks. _Rejected:_ native codec
  primitives while the Pudu forms meet the linear bound.
## Referenced by
[[src/Std/_MOC]] · [[Eval Bytes]] · [[architecture/STDLIB]]
