---
type: module
path: "@root/test-fixtures/stdlib/RejectsMissingConstructorPattern.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Testing]]"
grammar: "[[grammar/pudu]]"
depth_score: 0.44
depth_status: MEDIUM
coupling: 2.0
interface_stability: 1.0
tags: [module, fixture, diagnostic]
aliases: [Rejects Missing Constructor Pattern]
---

# Rejects Missing Constructor Pattern

## Purpose

Prove that a misspelled constructor in a pattern beneath a loaded standard-library qualifier is rejected at compile time.

## Interface

Exports an intentionally invalid `main`; it is compiled for diagnostics and never evaluated.

### Linkage

- **Requires:** [[Std Audio]], [[Type Check Pattern]].
- **Consumed by:** [[Standard Library Program Spec]].

## Algorithm

Call a real `Std.Audio` function, then spell its `InvalidChannels` failure variant incorrectly in an `if let` pattern.

## Negative Logic (Prohibited Paths)

- The miss must not fall back to a bare constructor or reach evaluation.

## Edge Cases

- The imported module has many valid exported members, allowing the checker to distinguish a module-member typo from an unknown receiver.

## Depth

DEPTH 0.44 (MEDIUM). A tiny fixture crosses the program graph and qualified pattern lookup.

## Grill Log

- **Q:** Use a fabricated module? **A:** No; use the exact public audio surface that exposed the defect. _Rationale:_ this preserves the production regression with minimal source. _Rejected:_ testing only a local sum type.

## Referenced by

[[Standard Library Program Spec]] · [[Type Check Pattern]]
