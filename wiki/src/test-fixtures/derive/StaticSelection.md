---
type: module
path: "@root/test-fixtures/derive/StaticSelection.pudu"
fidelity: Active
grammar: "[[grammar/pudu]]"
tags: [module, fixture, derive]
---

# Derive StaticSelection Fixture

## Purpose and contract

Static trait calls through a generic function's parameter, a derived impl for a generic record and an impl for Array[A], all decided by the types the calls chose.

## Grill Log

- **Q:** Look the owner up from a value? **A:** No; there is none. The call carries the selected types.

## References

[[Derive Library Spec]] · [[Derive Design]] · [[src/_MOC]]
