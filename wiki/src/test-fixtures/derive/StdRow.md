---
type: module
path: "@root/test-fixtures/derive/StdRow.pudu"
fidelity: Active
grammar: "[[grammar/pudu]]"
tags: [module, fixture, derive]
---

# Derive StdRow Fixture

## Purpose and contract

Derive Db.Row for a record with a renamed column, a nullable column and a Decimal, reading one valid row and refusing a row whose id has the wrong kind.

## Grill Log

- **Q:** Accept a text id for an Int field? **A:** No; the strict readers refuse it with WrongKind.

## References

[[Derive Library Spec]] · [[Derive Design]] · [[src/_MOC]]
