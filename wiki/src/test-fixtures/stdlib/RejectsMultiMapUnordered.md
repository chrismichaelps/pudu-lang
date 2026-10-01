---
type: module
path: "@root/test-fixtures/stdlib/RejectsMultiMapUnordered.pudu"
fidelity: Active
grammar: "[[grammar/pudu]]"
tags: [module, test, stdlib]
---

# RejectsMultiMapUnordered

## Purpose and interface

A function value cannot enter the ordered occurrence index. Add must refuse with E7008, matching the prior implementation.

## Dependencies and consumers

Imports [[Std MultiMap]]. The focused MultiMap checks run both evaluators.
The success fixture is also discovered by the full evaluator agreement oracle.

## Grill Log

Resolved: assert observable output and diagnostic codes; retain snapshots before
and after writes. No benchmark size change or timing assertion enters fixtures.

## Referenced by

[[src/_MOC]] · [[Std MultiMap]] · [[2026-10-01-multimap-performance]]
