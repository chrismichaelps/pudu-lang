---
type: module
path: "@root/test/native-progress.test.mjs"
fidelity: Active
aliases: [Native Progress Tests]
---
# Native Progress Tests

## Purpose and interface

Node test runner checks [[Native Progress Generator]] with explicit fixture
expectations: area completion, partial status, rounding, empty/full bar, malformed
tables, duplicate areas, marker errors, preservation and idempotence. CLI checks
use temporary repository-shaped copies to avoid changing the checkout.

## Resolved Grill Log

- **Q:** Merely compare generated output to itself? **A:** No; assert literal counts,
  percentages and bars, plus CLI exit status and file contents.
- **Q:** Need the compiler build? **A:** No; this changes documentation publishing only.

## Dependencies and consumers

[[Native Progress Generator]] · [[Native Progress Workflow]]

## Referenced by

[[src/_MOC]]
