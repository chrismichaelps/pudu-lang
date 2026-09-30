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

## Algorithm and invariants

Import each selected focused test explicitly and expose a stable descriptive label. Every
registered property executes through the same structured diagnostic or evaluator test harness;
adding a helper to an unused secondary property list is insufficient registration.

## Negative logic

No implementation semantics or broad exception suppression belong in the coordinator.

## Grill Log

- **Q:** Trust an unused per-file property list? **A:** No; the executable runner consumes this
  coordinator, so each new regression must be listed here. _Rejected:_ silently skipped tests.

## Referenced by

[[src/Pudu/_MOC]] · [[Eval Function Closure Tests]]
