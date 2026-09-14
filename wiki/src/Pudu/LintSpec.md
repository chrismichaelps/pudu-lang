---
type: module
path: "@root/test/Pudu/LintSpec.hs"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module, test, lint]
aliases: [Pudu Lint Spec]
---

# Pudu Lint Spec

## Purpose and evidence

Property-test typed Boolean findings, negative shapes, exact safe replacements, parenthesized-inner
refusal, deterministic ordering, and structural linearity. The large sequential fixture checks
the analyzer's published visited-expression count rather than timing a busy machine.

## Grill Log

- **Q:** Approve equivalence from output text alone? **A:** No. _Rationale:_ tests compile the source
  and require inferred Boolean types before linting.
- **Q:** Use a wall-clock threshold as the linearity oracle? **A:** No. _Rationale:_ structural work
  is deterministic; elapsed time is benchmark evidence, not a correctness property.

## Referenced by

[[Pudu Lint]] · [[Repository Test Runner]] · [[Pudu Test Cabal Manifest]]
