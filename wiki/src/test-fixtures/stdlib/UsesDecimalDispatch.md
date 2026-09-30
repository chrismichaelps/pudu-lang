---
type: module
path: "@root/test-fixtures/stdlib/UsesDecimalDispatch.pudu"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/pudu]]"
tags: [module, fixture, runtime, decimal]
aliases: [Uses Decimal Dispatch]
---

# Uses Decimal Dispatch

## Purpose and interface

Executable regression for #371. `main` returns five held assertions for direct Decimal trait
implementation calls, bounded generic calls, trait qualification, type qualification, and
retained trailing-zero rendering. Doubling preserves exact arithmetic for positive and negative
values.

## Governance and linkage

- The fixture passes through ordinary program loading, checking, and evaluation.
- A declared implementation uses the canonical Decimal runtime owner.
- Requires [[Eval Operator Access]], [[Eval Function Closure Tests]], and [[grammar/pudu]].
- Consumed by [[Runtime Evaluation Spec]].

## Negative Logic

No built-in doubling method or unchecked evaluator substitutes for implementation dispatch.

## Grill Log

- **Q:** Does checked expression coverage also need a program fixture? **A:** Yes; execute the
  same dispatch paths after module loading. _Rationale:_ runtime implementation registration
  must agree with owner discovery in a real module. _Rejected:_ accepting a successful check
  without executing the admitted call.

## Referenced by

[[Runtime Evaluation Spec]] · [[Eval Operator Access]]
