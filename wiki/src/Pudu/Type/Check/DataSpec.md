---
type: module
path: "@root/test/Pudu/Type/Check/DataSpec.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Testing]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.66
depth_status: DEEP
coupling: 3.0
interface_stability: 0.8
tags: [module, test, deep]
aliases: [Type Check Data Spec]
---

# Type Check Data Spec

## Purpose

Lock the type-system contracts for records, tuples, keyed collections, sum constructors, and positional and named-field patterns.

## Interface

`dataProperties` contributes focused `IO Property` cases to the compiler test runner. The exported helpers let narrower test groups reuse the same fixtures without duplicating language programs.

### Linkage

- **Requires:** [[Type Check]], [[Type Check Pattern]], [[Type Check Rule]], [[grammar/pudu]].
- **Consumed by:** the package test runner.

## Algorithm

Compile small complete Pudu modules or isolated expressions, then compare ordered diagnostic codes, inferred types, spans, messages, and help text with the language contract.

## Negative Logic (Prohibited Paths)

- No evaluator assertions, filesystem fixtures, snapshot rewriting, or tolerance for additional diagnostics.

## Edge Cases

- Qualified constructor patterns treat the qualifier as authoritative. A missing exported module constructor is `E3033`; a missing variant on a known type is `E3034`; neither may fall back to an unrelated bare constructor.
- Positional and named-field patterns receive the same qualified-name protection.

## Depth

DEPTH 0.66 (DEEP). One suite covers several interacting data-shape rules and guards their exact diagnostics.

## Grill Log

- **Q:** Is a successful nearby constructor sufficient evidence for a misspelled qualified pattern? **A:** No; assert both the valid spelling and the miss explicitly. _Rationale:_ the historical failure silently accepted the typo while other constructors continued to work. _Rejected:_ relying on the standard-library runtime fixture alone.
- **Q:** May a qualified miss fall back to a bare constructor of the same name? **A:** No. _Rationale:_ qualification is an explicit ownership choice and fallback makes meaning depend on unrelated loaded modules. _Rejected:_ global variant lookup after qualified lookup fails.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Check Pattern]]

## Built-in scope diagnostic boundary (#759)

Keep exact E3034/module-import help for unimported Result functions. A locally
declared sum named Result retains E3034/variant-name help for its missing variant.
Resolved Grill Log: canonical declaration ownership decides this diagnostic
boundary; a familiar basename must not trigger an unrelated import suggestion.
See [[Builtin Scope Delivery]].
