---
type: module
path: "@root/src/Pudu/Type.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.6
depth_status: MEDIUM
coupling: 3.0
interface_stability: 0.8
tags: [module, medium]
aliases: [Type Boundary]
---

# Type Boundary

## Purpose

Expose the typing phase: check a resolved module and publish the type each expression was given.

## Interface

### Signatures

```haskell
newtype TypeInfo
checkTypes :: Module -> (TypeInfo, [Diagnostic])
checkTypesWith :: ImportTypes -> Module -> (TypeInfo, [Diagnostic])
typeAt :: TypeInfo -> Span -> Maybe Type
narrowestAt :: Int -> TypeInfo -> Maybe Type
narrowestSpanAt :: Int -> TypeInfo -> Maybe ((Int, Int), Type)
widestWithin :: Int -> Int -> TypeInfo -> Maybe Type
renderType :: Type -> Text
```

### Governance

- `checkTypesDetailed` reports the module frame's final schemes alongside the per-expression types.
  Tooling that documents or searches a module needs the generalised type of every declared name,
  and re-deriving it from written syntax would let a tool's answers drift from the compiler's.

- The published `TypeInfo` is keyed by the span an expression occupies, so tooling answers "what is this?" without re-running the checker.
- `ModuleTypes` carries `moduleMethods`: the methods this module's declarations provide, by owner,
  with their schemes (see [[Type Env]]).
- `narrowestSpanAt` answers for a point: the shortest recorded span covering it, the first in key
  order among equal widths. It is one pass over the table keeping the best so far; a hover or a
  completion detail asks it several times per request, and sorting the table for each would repeat
  that work.
- `widestWithin` answers for a region rather than an exact span, which is what an interactive entry or an editor selection can supply.
- Checking runs only on a module whose names all resolved. An unresolved name has no type, and reporting one would explain the same defect twice.
- Type diagnostics use the `E3xxx` family from [[architecture/SEMANTICS]]'s diagnostic contract.
- `checkTypesWith` is the loaded-program entry and `checkTypes` delegates with empty imports, preserving isolated compilation behavior.

### Linkage

- **Requires:** [[Type Check]], [[Type Interface]], [[Type Value]], [[Syntax Tree]], [[Diagnostic Model]], [[Source]].
- **Consumed by:** [[Compiler Pipeline]] and [[Pudu REPL]].

## Algorithm

Run the checker, collect the recorded expression types into a map keyed by span offsets, and return it beside the diagnostics.

## Negative Logic (Prohibited Paths)

- No evaluation, no ownership analysis, no exhaustiveness checking, no lowering, and no re-derivation of what resolution already established.

## Edge Cases

- A module with type errors still publishes the types it did infer, so an editor can keep answering questions about the parts that checked.

## Depth

DEPTH 0.60 (MEDIUM). One surface hides formation, unification, and the checking walk.

## Grill Log

- **Q:** Should the checker return an annotated tree? **A:** Not yet; it publishes a span-keyed map. _Rationale:_ a typed IR is the right home for annotations, and inventing one before lowering exists would freeze a shape no consumer has asked for. _Rejected:_ rewriting the syntax tree with types; a parallel typed AST.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Compiler Pipeline]] · [[Pudu REPL]] · [[Semantics]]

## Places

`checkTypesDetailed` takes the `var` use spans from the caller's resolution; `checkTypes` and `checkTypesWith` resolve the module themselves to obtain them. See [[ADR-0022-lending-a-place]].
