---
type: module
path: "@root/src/Pudu/Eval/Builtin/Definition.hs"
fidelity: Active
domain: "[[Execution Result]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.25
depth_status: SHALLOW
coupling: 1.0
interface_stability: 0.9
tags: [module, shallow, runtime]
aliases: [Eval Builtin Definition]
---

# Eval Builtin Definition

## Purpose

Name the evaluator's closed set of wired-in functions and provide the one canonical mapping from
each tag to its source-level binding.

## Interface

```haskell
data Builtin = ...
builtinName :: Builtin -> Text
```

[[Eval Value]] re-exports this interface so existing consumers keep the same import surface.

## Governance

- This module contains definitions only. Application, effect execution, typing, and installation
  remain in their existing phase-specific modules.
- Every constructor has exactly one source-level name in the total `builtinName` match.
- Adding a wired-in function requires corresponding evaluator and prelude work; a constructor here
  does not by itself expose a language feature.

## Linkage

- **Requires:** host `Text` only.
- **Consumed by:** [[Eval Value]], which preserves the established public import boundary.

## Negative Logic (Prohibited Paths)

- No runtime `Value` dependency. Introducing one would recreate the size and dependency pressure
  this definition seam removes.
- No dispatch or host effects. Those belong to [[Eval Builtin]] and [[Eval Effect]].

## Grill Log

- **Q:** Why split definitions instead of granting [[Eval Value]] a size exception? **A:** The
  builtin tags and name table form a complete, dependency-light seam and account for enough code to
  return `Value.hs` below 500 lines. _Rationale:_ callers retain source compatibility through
  re-export while the split gives the closed vocabulary one auditable home. _Rejected:_ an
  undocumented size exception; moving unrelated value constructors or ordering logic.
- **Q:** Should callers import this module directly? **A:** Not by default. _Rationale:_
  [[Eval Value]] remains the compatibility boundary, while this module is an internal depth split.
  _Rejected:_ rewriting every evaluator import for a no-semantics refactor.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Eval Value]] · [[Eval Builtin]] · [[Eval Effect]]

## Word-map cardinality kernel

`wordMapPopCount[K](Map[K, UInt64]) -> UInt128` is a pure wired-in reduction consumed by
[[Std BitSet]]. It counts payload bits independently of keys, including zero payloads, and avoids
entry-array materialization. The runtime checks UInt64 kind/range before conversion and reports
E7001 for invalid payloads or receiver, E7003 for wrong arity. Registration covers semantic names,
type signatures, installation, builtin naming and pure dispatch. No IO or FFI capability is required.

Resolved Grill Log: Use an explicit primitive rather than recognize a library function by name,
so shadowing and ordinary calls retain their meaning. Result width is UInt128; an Int-sized host
map cannot contain enough 64-bit words to overflow it. This remains unvalidated.
