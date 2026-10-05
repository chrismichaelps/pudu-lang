---
type: module
path: "@root/test-fixtures/derive/Main.pudu"
fidelity: Active
grammar: "[[grammar/pudu]]"
tags: [module, fixture, derive]
---

# Derive Integration Fixture

## Purpose and contract

Exercise inline record and Sum requests and an external local record request
through the real compiler. The record template unrolls two literal iterations
and answers `tagrr`; the Sum template answers `sum`. Calling all three generated
methods answers `tagrrtagrrsum`, preserving ordinary construction and dispatch.
Attributes remain inert when no template reads them.

## Grill Log

- **Q:** Let a positive fixture only declare unused templates? **A:** Invoke the
  generated methods and assert their output. _Rejected:_ syntax-only success
  standing for graph elaboration.

## References

[[src/Pudu/Type/Check/DeriveSpec]] · [[Derive Design]] · [[src/_MOC]]
