---
type: module
path: "@root/test-fixtures/stdlib/UsesChecksumAll.pudu"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
tags: [module, fixture, stdlib, hashing]
aliases: [Uses Checksum All]
---

# Uses Checksum All

## Purpose and interface

Executable fixture for [[Std Checksum]]. Its `main` returns 15 held assertions reaching every export:
each algorithm's published check value for `123456789` (and the pangram for CRC-32), the empty
input, chained updates equal to the whole, `0` as the start of a stream, a one-bit change moving
every checksum, and fixed-width hex with leading zeros.

## Grill Log

- **Q:** Where do the expected values come from? **A:** The algorithms' published check values.
  _Rationale:_ vectors produced by the implementation under test prove only consistency.

## Referenced by

[[Std Checksum]] · [[Eval Checksum]] · [[Runtime Evaluation Spec]]
