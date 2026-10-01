---
type: module
path: "@root/test-fixtures/stdlib/UsesMultiMapNumeric.pudu"
fidelity: Active
grammar: "[[grammar/pudu]]"
tags: [module, test, stdlib]
---

# UsesMultiMapNumeric

## Purpose and interface

Exercise the numeric occurrence index and native dependency-region loop with
signed pairs, duplicate counts, persistent snapshots, ordered Map views,
remove/add transitions, host-range fallback, multiple calls, conditional updates, short-circuiting and condition-side writes.
Fourteen assertions must pass. Transfers and unrelated function calls must use ordinary evaluation.
Print an exact success marker only when all checks pass; the fixture runs in
both evaluators and against the original Std.MultiMap implementation.

## Dependencies and consumers

Imports [[Std MultiMap]]. Discovered by the full evaluator agreement fixture
oracle and used for focused before/after compatibility validation.

## Grill Log

Resolved: verify observable contents and output independently of the optimized
representation. Use small differing loop shapes and trip counts rather than a
timing test or a copied benchmark. Keep snapshot assertions across every update.

## Referenced by

[[src/_MOC]] · [[Eval MultiMap Kernel]] · [[Std MultiMap]]
