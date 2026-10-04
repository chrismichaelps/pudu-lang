---
type: module
path: "@root/test/Pudu/Compiler/ProgramSpec.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Testing]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.2
depth_status: SHALLOW
coupling: 7.0
interface_stability: 0.9
tags: [module, test]
aliases: [Program Spec]
---

# Program Spec

## Purpose

Aggregate the layered program-compiler properties into one list for the package test runner.

## Interface

`programProperties :: [(String, IO Property)]`.

### Linkage

- **Requires:** [[Program Graph Spec]], [[Standard Library Program Spec]],
  [[Language Foundation Program Spec]], and the cache, evaluation, foreign, and type-boundary specs.
- **Consumed by:** the package test runner.

## Algorithm

List each imported property with its description; no property is built here.

Register [[Program Cache Spec]]'s product-publication boundary: full analysis,
cold/warm executable results and rejected-source diagnostics. Resolved Grill Log:
the product policy must have observable execution and tooling contract evidence.

## Negative Logic (Prohibited Paths)

- No test logic; a property is defined in the spec that owns its subject.

## Edge Cases

- A property exported by a spec but absent here never runs.

## Depth

DEPTH 0.2 (SHALLOW). A registry by design.

## Grill Log

- **Q:** Why keep an aggregate rather than one list per spec? **A:** The runner imports one list per
  subsystem. _Rationale:_ stable runner wiring. _Rejected:_ runner imports of every spec.

## Referenced by

[[src/Pudu/Compiler/Program/_MOC]]

Imported constant folding is registered from [[Program Cache Spec]], covering imported constructors,
all import forms, transitive frozen products, cache equivalence and capability refusal (#373).
