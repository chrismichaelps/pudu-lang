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

`ModuleTypes` carries `moduleSelections`, the static selections by reference span.

## Interface

### Signatures

```haskell
data TypeInfo
checkTypes :: Module -> (TypeInfo, [Diagnostic])
checkTypesWith :: ImportTypes -> Module -> (TypeInfo, [Diagnostic])
typeAt :: TypeInfo -> Span -> Maybe Type
typeAtOffsets :: Int -> Int -> TypeInfo -> Maybe Type
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
  with their schemes and name spans (see [[Type Env]]).
- Its `moduleTypeInfo` field is intentionally lazy. Checking diagnostics and
  integer kinds must not construct the expression lookup map that only tooling
  reads. The completed checker facts and substitution remain the sole source;
  a demanded table is built once and retains the existing keys and values.
- `narrowestSpanAt` answers for a point: the shortest recorded span covering it, the first in key
  order among equal widths. It is one pass over the table keeping the best so far; a hover or a
  completion detail asks it several times per request, and sorting the table for each would repeat
  that work.
- `widestWithin` visits only the entries starting inside the region — the table is keyed by start
  offset — and keeps the widest contained one; `typeAtOffsets` is the exact lookup a known span
  needs.
- `widestWithin` answers for a region rather than an exact span, which is what an interactive entry or an editor selection can supply.
- Checking runs only on a module whose names all resolved. An unresolved name has no type, and reporting one would explain the same defect twice.
- Type diagnostics use the `E3xxx` family from [[architecture/SEMANTICS]]'s diagnostic contract.
- `checkTypesWith` is the loaded-program entry and `checkTypes` delegates with empty imports, preserving isolated compilation behavior.

### Linkage

- **Requires:** [[Type Check]], [[Type Interface]], [[Type Value]], [[Syntax Tree]], [[Diagnostic Model]], [[Source]].
- **Consumed by:** [[Compiler Pipeline]] and [[Pudu REPL]].

## Algorithm

Run the checker, retain all complete-span facts and index only authored facts from the current snapshot for editor offset queries.

## Negative Logic (Prohibited Paths)

- No evaluation, no ownership analysis, no exhaustiveness checking, no lowering, and no re-derivation of what resolution already established.

## Edge Cases

- A module with type errors still publishes the types it did infer, so an editor can keep answering questions about the parts that checked.

## Depth

DEPTH 0.60 (MEDIUM). One surface hides formation, unification, and the checking walk.

## Grill Log

- **Q:** Build the expression map while admitting every `ModuleTypes` result?
  **A:** Defer only this derived lookup product until a consumer asks for it.
  _Rationale:_ phase attribution measures 87.5 MB for this unused map on an
  8,000-branch check. Strict diagnostics and executable integer kinds still run
  normally. _Rejected:_ skipping type checking, dropping editor facts, changing
  inferred types, or sorting the facts without a measured latency win.
- **Q:** Should the checker return an annotated tree? **A:** Not yet; it publishes a span-keyed map. _Rationale:_ a typed IR is the right home for annotations, and inventing one before lowering exists would freeze a shape no consumer has asked for. _Rejected:_ rewriting the syntax tree with types; a parallel typed AST.
- **Q:** Carry selections beside integer kinds through the evaluator? **A:** No; they become explicit syntax once, in [[Compiler Literals]].

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Compiler Pipeline]] · [[Pudu REPL]] · [[Semantics]]

## Places

`checkTypesDetailed` takes the `var` use spans from the caller's resolution; `checkTypes` and `checkTypesWith` resolve the module themselves to obtain them. See [[ADR-0022-lending-a-place]].

## Complete expression identity

`TypeInfo` carries a complete `Map Span Type` for exact compiler queries and a
separate `Map (Int, Int) Type` for authored editor queries in the module's own
snapshot. Generated nodes and foreign snapshots never enter the offset index.
Exact `typeAt` queries use the full span; offset query complexity stays unchanged.

- **Q:** Collapse generated types into the hover map? **A:** No. _Rationale:_ a
  template position has different types in different instantiations. _Rejected:_
  last expansion wins or a linear rescan on every tooling query.
