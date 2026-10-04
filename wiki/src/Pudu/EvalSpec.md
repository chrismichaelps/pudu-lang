---
type: module
path: "@root/test/Pudu/EvalSpec.hs"
fidelity: Active
tags: [module, test]
aliases: [Eval Test Coordinator]
---

# Eval Test Coordinator

## Purpose and interface

Register the focused evaluator properties in the executable test runner. The exported property list is consumed by `test/Main.hs`.

Decimal equality regressions cover nested aggregates, collection lookup, unequal values, and
representation-preserving rendering.

## Algorithm and invariants

Import each selected focused test explicitly and expose a stable descriptive label. Every
registered property executes through the same structured diagnostic or evaluator test harness;
adding a helper to an unused secondary property list is insufficient registration.
Explicitly register `testSlotScopes` from [[Eval Function Closure Tests]] so
binding-order, scope and capture admission regressions execute in the full suite.

## Negative logic

No implementation semantics or broad exception suppression belong in the coordinator.

## Grill Log

- **Q:** Trust an unused per-file property list? **A:** No; the executable runner consumes this
  coordinator, so each new regression must be listed here. _Rejected:_ silently skipped tests.

## Referenced by

[[Eval Binding Flow Tests]] covers pure-loop kernel result, condition-write,
short-circuit, overflow and constant-limit evidence through its registered loop
family. Resolved Grill Log: extend the executed family rather than an uncalled
local property list.

[[src/Pudu/_MOC]] · [[Eval Function Closure Tests]] · [[Eval Data Tests]]
