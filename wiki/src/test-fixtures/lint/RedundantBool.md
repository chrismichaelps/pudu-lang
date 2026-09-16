---
type: module
path: "@root/test-fixtures/lint/RedundantBool.pudu"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/pudu]]"
tags: [module, test, lint, fixture]
aliases: [Redundant Boolean Lint Fixture]
---

# Redundant Boolean Lint Fixture

## Purpose and contract

Provide one valid typed Pudu module containing each source orientation admitted by `W7101`, plus
nearby Boolean expressions that must not receive a fix. The live command gate copies this file,
requires JSON findings, applies fixes, recompiles, and requires a clean second lint.

## Grill Log

- **Q:** Use malformed or untyped expressions to make matching easy? **A:** No. _Rationale:_ the
  production rule is type-proven and the fixture must cross the real compiler boundary.

## Referenced by

[[Pudu Lint]] · [[Pudu Lint Spec]] · [[Repository Gates]]
