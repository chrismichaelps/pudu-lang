---
type: module
path: "@root/test-fixtures/stdlib/RejectsMultiMapOverflow.pudu"
fidelity: Active
grammar: "[[grammar/pudu]]"
tags: [module, test, stdlib]
---

# RejectsMultiMapOverflow

## Purpose and interface

A forged occurrence count at the 64-bit Int maximum must fail with E7005 instead of overflowing during add. The focused script checks this on the supported 64-bit host.

## Dependencies and consumers

Imports [[Std MultiMap]]. The focused MultiMap checks run both evaluators.
The success fixture is also discovered by the full evaluator agreement oracle.

## Grill Log

Resolved: assert observable output and diagnostic codes; retain snapshots before
and after writes. No benchmark size change or timing assertion enters fixtures.

## Referenced by

[[src/_MOC]] · [[Std MultiMap]] · [[2026-10-01-multimap-performance]]
