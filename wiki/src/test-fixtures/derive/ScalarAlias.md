---
type: module
path: "@root/test-fixtures/derive/ScalarAlias.pudu"
fidelity: Active
grammar: "[[grammar/pudu]]"
tags: [module, fixture, derive]
---

# Derive Scalar Alias Refusal

## Purpose and contract

An Int alias requesting a Sum derive produces exactly E3091. There is no
aggregate shape to reflect and no generated implementation or executable product.

## Grill Log

- **Q:** Guess an empty Sum shape for an alias? **A:** Refuse nonaggregates at
  their request. _Rejected:_ accepting a request because its method is unused.

## References

[[src/Pudu/Type/Check/DeriveSpec]] · [[Derive Design]] · [[src/_MOC]]
