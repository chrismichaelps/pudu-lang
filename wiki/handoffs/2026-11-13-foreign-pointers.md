---
type: handoff
status: ACTIVE
issue: 877
aliases: [Foreign Pointer Delivery]
---

# Foreign Pointer Delivery

Language Architect → Backend, Semantic and Runtime Engineers after review of
[[Foreign Pointers and Runs]]. The first implementation owns non-null foreign
loans to one scalar or record, including writeback through an ordinary mutable
place. Later partitions own arrays, bounds, nullable and returned values, and
function pointers.

## Resolved Grill Log

- A loan expires at return from the foreign call. The bridge copies in and
  writes back the final mutable values using existing Pudu place rules.
- The target ABI supplies record layout. Interpreter and native evidence
  includes nested records with padding as well as scalar widths.
- Success, overlapping loans, forbidden pointees and forbidden results need
  focused checks in both execution paths. Array capacity, null and lifetime
  cases belong to the partitions that introduce those crossings.

## Exact next action

Review ADR-0030's foreign loan contract, then resolve the parser, checker,
interpreter and native module mirrors for the first implementation partition.

## Referenced by

[[handoffs/_MOC]] · [[Foreign Pointers and Runs]]
