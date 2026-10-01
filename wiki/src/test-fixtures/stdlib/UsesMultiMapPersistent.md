---
type: module
path: "@root/test-fixtures/stdlib/UsesMultiMapPersistent.pudu"
fidelity: Active
grammar: "[[grammar/pudu]]"
tags: [module, test, stdlib]
---

# UsesMultiMapPersistent

## Purpose and interface

Persistence, duplicates, empty-key removal, missing membership, composite keys/values, Decimal key representatives (the most recent equal key keeps the spelling `[1.5]`), and pure constant folding. Thirteen assertions must pass and print an exact success line. A same-named user function must not be selected as a primitive; the imported Std wrapper must retain its own captured builtin.

## Dependencies and consumers

Imports [[Std MultiMap]]. The focused MultiMap checks run both evaluators.
The success fixture is also discovered by the full evaluator agreement oracle.

## Grill Log

Resolved: assert observable output and diagnostic codes; retain snapshots before
and after writes. No benchmark size change or timing assertion enters fixtures.

## Referenced by

[[src/_MOC]] · [[Std MultiMap]] · [[2026-10-01-multimap-performance]]
