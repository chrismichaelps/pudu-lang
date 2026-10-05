---
type: module
path: "@root/test/Pudu/Type/CheckSpec.hs"
fidelity: Active
tags: [module, test]
aliases: [Type Test Coordinator]
---

# Type Test Coordinator

## Purpose and interface

Register primitive, pattern, control-flow, generic, trait, and system checker properties. The exported property list is consumed by `test/Main.hs`.

The constructor-namespace regression compiles complete module graphs with Std.Json and
same-named local variants, preserving imported nominal identity and instantiated payloads.

## Algorithm and invariants

Register [[Type Check Derive Spec]] contract, source, scoped-bound and substitution
properties beside the existing definition-checking fixtures.

Import each selected focused test explicitly and expose a stable descriptive label. Every
registered property executes through the same structured diagnostic or evaluator test harness;
adding a helper to an unused secondary property list is insufficient registration.

## Negative logic

No implementation semantics or broad exception suppression belong in the coordinator.

## Grill Log

- **Q:** Trust an unused per-file property list? **A:** No; the executable runner consumes this
  coordinator, so each new regression must be listed here. _Rejected:_ silently skipped tests.

## Referenced by

[[src/Pudu/_MOC]] · [[Type Check Pattern Spec]]
