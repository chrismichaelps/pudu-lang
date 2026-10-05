---
type: module
path: "@root/test-fixtures/derive/SumShapes.pudu"
fidelity: Active
grammar: "[[grammar/pudu]]"
tags: [module, fixture, derive]
---

# Derive Sum Shapes Fixture

## Purpose and contract

Instantiate a shape-independent Sum template for a direct sum and a transparent
sum alias. `Meta.nameOf` folds to the underlying declaration name. Invoke both
generated methods and assert `Shape:sumOther:sum` in ordinary evaluation.
The alias does not create a second nominal identity.

## Grill Log

- **Q:** Treat scalar aliases as Sum? **A:** No. Use a real sum alias here and
  keep a scalar alias as an explicit refusal. _Rejected:_ an unused method
  masking an invalid aggregate request.

## References

[[src/Pudu/Type/Check/DeriveSpec]] · [[Derive Design]] · [[src/_MOC]]
