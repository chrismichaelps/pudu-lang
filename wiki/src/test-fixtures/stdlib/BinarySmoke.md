---
type: module
path: "@root/test-fixtures/stdlib/BinarySmoke.pudu"
fidelity: Active
aliases: [Binary Facade Smoke]
tags: [module, test, stdlib, serialization]
---
# Binary Facade Smoke

A record derives Binary.Encode/Binary.Decode and JSON Encode/Decode and executes both paths.
Checks framed binary round trips, malformed-magic typed refusal, CRC refusal, a node round trip,
and a sum payload whose skipped cache must ignore a supplied wire value. Emits `binary facade: ok`.

## Resolved Grill Log

- **Q:** Check the derive names only through compilation? **A:** No; execute both protocols on
  one record, and exercise native encode/decode and the framing error path through the real CLI.
- **Q:** Test skipped fields only when absent? **A:** No; explicitly supply the skipped sum field
  on the wire, the case that reproduced the decoder regression.

## Referenced by

[[Std Binary]] · [[Binary Facade Gate]] · [[src/_MOC]]
