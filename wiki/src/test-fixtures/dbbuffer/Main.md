---
type: module
path: "@root/test-fixtures/dbbuffer/Main.pudu"
fidelity: Active
tags: [test, database, framing]
aliases: [Database Buffered Read Fixture]
---
# Database Buffered Read Fixture

## Purpose and interface

Execute the actual database session reader over a deterministic transport substitute. The fixture
exits zero only after exact framing, read-count, budget and cleanup assertions pass.

## Algorithm

A batch of small messages must use two transport reads, preserving every payload. Fragmented
headers and bodies still complete. The buffer cap applies to read-ahead, including subsequent
messages. Empty-body frames complete without an extra read. Oversized and malformed advertised
frames close without body reads. Invalid local limits refuse without touching the transport;
incomplete EOF closes and reports the typed failure.

## Resolved Grill Log

- **Q:** Gate on elapsed time? **A:** No; exact transport calls prove coalescing without timing noise.
- **Q:** Substitute the reader too? **A:** No; the real session implementation is the subject.

## Referenced by

[[src/_MOC]] · [[Std Db Session]] · [[Database Fixture Transport]]
