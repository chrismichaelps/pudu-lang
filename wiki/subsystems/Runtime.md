---
type: subsystem
tags: [subsystem]
aliases: [Runtime]
---

# Runtime

## Purpose

Provide deterministic [[Execution Result]] behavior for checked [[Core IR]] and the minimal native support required by [[Standard Library]] contracts.

## Owns

Interpreter · runtime values · panic/cancellation model · deterministic destruction support · standard-library runtime primitives.

## Boundaries

- Never parses or type-checks source.
- Interpreter consumes Core IR and explicit environment/input capabilities.
- Native runtime exposes a versioned C ABI generated/consumed only by [[Backend]].

## Grill Log

- **Q:** Should the interpreter use Haskell exceptions for Pudu control flow? **A:** No; represent failure, return, panic, and cancellation explicitly. _Rationale:_ exception leakage would make conformance and cleanup order opaque. _Rejected:_ `ExceptT SomeException` catch-all.
- **Q:** Should all values be boxed? **A:** The interpreter may box algebraically for clarity; native representation is backend-owned. _Rationale:_ interpreter layout is not observable. _Rejected:_ forcing native layout into semantic evaluation.

## Referenced by

[[architecture/OVERVIEW]] · [[Semantics]] · [[Backend]] · [[Tooling]]
