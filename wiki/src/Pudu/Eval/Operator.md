---
type: module
path: "@root/src/Pudu/Eval/Operator.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.45
depth_status: MEDIUM
coupling: 2.0
interface_stability: 0.8
tags: [module, medium]
aliases: [Eval Operator]
---

# Eval Operator

## Purpose

Own operator and access semantics for [[Evaluator]]. `readIndex` handles tuples, strings, and arrays; `readMember` dispatches fields and methods including the full array accessor method table (42 methods: core accessors, mutation, higher-order, construction, aggregation, ordering, and transformation).

## Interface

The exported signatures are the module header's export list; [[Evaluator]] is the only consumer, and every function here is total with respect to the values the earlier phases admit.

### Governance

- Data and mechanics only: nothing here decides program meaning that [[architecture/SEMANTICS]] assigns to another phase.
- Failures are reported as `E7xxx` diagnostics through [[Eval Env]], never as host exceptions or partial values.
- Every operation is defined for the value shapes the evaluator can produce, and says so explicitly for the shapes it cannot.

### Linkage

- **Requires:** [[Eval Value]], [[Syntax Tree]], [[Diagnostic Model]].
- **Consumed by:** [[Evaluator]].

## Algorithm

Direct structural recursion over the value or syntax shape; no caching, no mutation, no reflection.

## Negative Logic (Prohibited Paths)

- No typing, coercion, dispatch, IO, or ownership behaviour.

## Edge Cases

- A shape this module cannot handle produces a diagnostic naming the shape, never a default value.

## Depth

DEPTH 0.45 (MEDIUM). It keeps one concern out of [[Evaluator]], which would otherwise exceed the size the delivery rules allow.

## Grill Log

- **Q:** Why a separate module rather than more of [[Evaluator]]? **A:** Because the walker would pass 500 lines and stop being reviewable. _Rationale:_ the split follows a real seam — values, environment, matching, and operators are independently testable. _Rejected:_ one large evaluator file.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Evaluator]]
