---
type: module
path: "@root/src/Pudu/Eval/Call/Path.hs"
fidelity: Active
domain: "[[Execution Result]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.5
depth_status: MEDIUM
coupling: 3.0
interface_stability: 0.8
tags: [module, medium, runtime]
aliases: [Eval Call Path]
---

# Eval Call Path

## Purpose

Resolve dotted module and member paths, qualified callees, type argument syntaxes, and longest-binding identifier prefixes during runtime evaluation.

`A.member` with `A` bound to a witness reaches the witnessed owner's method, holding the owner's own arguments for its implementation's parameters (`witnessMethod`, `selectTypes`). `witnessOf` turns written type syntax into witnesses. A generated canonical owner path resolves by its type's own name, and a generated canonical variant path the defining module never imported reads as that variant's constructor.

## Interface

```haskell
readPath :: Span -> NonEmpty Text -> Evaluator Value
readName :: Span -> Text -> Evaluator Value
pathValue :: Expression -> Evaluator (Maybe Value)
lastPathSegment :: ModuleName -> Text
flattenPath :: Expression -> Maybe [Text]
longestBinding :: NonEmpty Text -> Evaluator (Maybe (Value, [Text]))
qualifiedCallee :: Located Expression -> [Value] -> Evaluator (Maybe Value)
qualifiedParts :: Expression -> Maybe (Text, Text)
typeArgumentNames :: Expression -> Maybe ([Text], Located Expression)
typeArgumentName :: Located TypeSyntax -> Text
```

### Governance

- Extracted from `Pudu.Eval.Call` to enforce strict modular file length limits (< 500 lines).
- `readPath` resolves a dotted path longest-binding-first, after honoring a local first segment, then walks trailing field accesses via `readMember`.
- `pathValue` flattens member access syntax chains into dotted strings for direct environment lookup when every part is a valid identifier.
- `qualifiedCallee` resolves method calls qualified by declaring trait or concrete type (e.g., `Trait.method(receiver)`), checking receiver owners dynamically.
- `qualifiedParts` guards qualification to identifiers starting with an uppercase letter, filtering nominal candidates before lexical admission distinguishes constants and witnesses.
- `typeArgumentNames` extracts written nominal type annotations from type application syntax to preserve caller-provided integer conversion targets at runtime.

### Linkage

- **Requires:** [[Eval Env]], [[Eval Value]], [[Eval Loop]], [[Eval Operator]], [[Eval Install]], [[Frontend Syntax Tree]].
- **Consumed by:** [[Eval Call]].

## Algorithm

- `longestBinding` generates all non-empty prefix sublists in descending length order, querying the evaluator environment with `lookupName` until the first match is found.
- `readPath` folds subsequent path segments across the base value using `readMember`.
- `qualifiedCallee` extracts `(typeOrTrait, method)`, inspecting direct binding first and receiver owner fallback second.

## Negative Logic (Prohibited Paths)

- No circular dependency on [[Eval Call]]; path resolution never invokes closures or full call pipelines directly.
- No type erasure before reading syntax; type application arguments are retained purely as syntax markers.

## Grill Log

- **Q:** Why extract path resolution into `Pudu.Eval.Call.Path`?
  **A:** `Pudu.Eval.Call` was 563 lines. Moving AST path navigation, longest-prefix searching, and callee qualification into a dedicated submodule leaves `Call.hs` focused on function application, scope joining, and thread invocation (< 400 lines).
- **Q:** Why restrict `qualifiedParts` to uppercase identifiers?
  **A:** In Pudu syntax, traits, types, and modules begin with an uppercase letter; testing lowercase identifiers for trait method resolution wastes environment lookups on every local member call.
- **Q:** Why keep `readMember` in `Pudu.Eval.Operator` rather than here?
  **A:** `readMember` is a general property access operator used across operators, whereas `Path` specifically handles identifier chains and callee prefixes.

- **Q:** Search for `point.x` as a module member before reading `point`? **A:** Not when `point` is a
  local. _Rationale:_ a value's own name never contains a dot, so a local first segment cannot begin
  a module path, and the failing search through every module's frame cost a sixth of a record-heavy
  loop (#423). A first segment that is not local keeps the longest-binding search.
- **Q:** Let a generated path fall back for any unbound name? **A:** No; only for generated spans, which checking proved.

## Referenced by

[[Eval Call]] · [[src/Pudu/Eval/_MOC]]

## Single-segment names

A bare name goes directly to lookupName and the existing undefined-name refusal.
It cannot have a dotted module prefix or trailing member, so it bypasses empty
prefix generation. Dotted paths keep their exact existing algorithm.

Resolved Grill Log: skip provably empty path work, without changing lexical or
implementation lookup, diagnostic spans, or name-lookup tallies.

`readName` exposes this same bare-name branch for the tree's operand path and
permits inlining. Resolved Grill Log: share the undefined-name diagnostic and
lookup tally rather than introducing a second name-resolution policy.

## Lexical member admission (#471)

qualifiedCallee returns Nothing immediately for an ordinary local head, skipping both dotted export lookup and receiver-owner fallback. A TypeWitnessValue retains witnessed method selection and its fallback. qualifiedPath performs the same local/witness distinction for explicit type-applied call dispatch; retain uppercase filtering only after lexical admission. Resolved Grill Log: constants may qualify ordinary value members; both evaluators must honor the same local frame and restore the outer namespace on exit.
