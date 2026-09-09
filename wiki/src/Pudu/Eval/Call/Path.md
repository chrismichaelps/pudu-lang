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

## Interface

```haskell
readPath :: Span -> NonEmpty Text -> Evaluator Value
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
- `readPath` resolves a dotted path longest-binding-first, ensuring linked modules take precedence over shorter prefixes while cleanly walking trailing field accesses via `readMember`.
- `pathValue` flattens member access syntax chains into dotted strings for direct environment lookup when every part is a valid identifier.
- `qualifiedCallee` resolves method calls qualified by declaring trait or concrete type (e.g., `Trait.method(receiver)`), checking receiver owners dynamically.
- `qualifiedParts` guards qualification to identifiers starting with an uppercase letter, ensuring local variables and parameters never trigger redundant trait/type qualification queries.
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

## Referenced by

[[Eval Call]] · [[src/Pudu/Eval/_MOC]]
