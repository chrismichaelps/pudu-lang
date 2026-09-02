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
