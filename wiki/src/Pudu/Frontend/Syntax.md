---
type: module
path: "@root/src/Pudu/Frontend/Syntax.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.53
depth_status: MEDIUM
coupling: 1.0
interface_stability: 1.0
tags: [module, medium]
aliases: [Syntax]
---

# Syntax

> `{-| @Program.Syntax.Module — exposes recoverable surface structure -}`

## Purpose

Expose the untyped syntax API by re-exporting [[Syntax Located]], [[Syntax Name]], and [[Syntax Tree]]. The façade contains no data definitions or parsing logic.

## Interface

### Signatures

```haskell
module Pudu.Frontend.Syntax
  ( module Pudu.Frontend.Syntax.Located
  , module Pudu.Frontend.Syntax.Name
  , module Pudu.Frontend.Syntax.Tree
  ) where
```

### Governance

- Every externally meaningful node is located; leaf operators are preserved textually in their containing located expression span.
- Invalid nodes are explicit recovery poison and never compile.
- Syntax represents written constructs; desugaring belongs to [[Semantics]].
- Null is represented so semantic analysis can reject it outside unsafe.

### Linkage

- **Requires:** [[Syntax Located]], [[Syntax Name]], [[Syntax Tree]], [[Source]], [[Pudu Program]], [[Pudu Type]], [[grammar/pudu]], [[grammar/haskell]].
- **Consumed by:** later parser, compiler-pipeline, name-resolution, and formatter modules through [[Frontend]].

## Algorithm

Re-export the three syntax ownership modules without adding aliases, wrappers, or logic.

## Negative Logic (Prohibited Paths)

- No symbol IDs, inferred types, ownership states, or lowered control flow.
- No host function values or evaluator closures.
- No erased invalid/recovery nodes.
- No source text copies beyond literal/identifier payloads required by later phases.

## Edge Cases

- Empty blocks have no statements/result and evaluate semantically to unit.
- One-element tuple types require a trailing comma in syntax; parentheses alone group.
- Else-if is represented as `else` containing a nested `IfExpression`.
- Missing nodes become located invalid variants at the recovery position.

## Depth

DEPTH 0.53 (MEDIUM). The API is necessarily broad because it models syntax, but it hides location uniformity and phase-boundary invariants. Deletion would couple parser data directly to semantics and tooling.

## Grill Log

- **Q:** One AST for all compiler phases? **A:** No; this is explicitly untyped and recovery-capable. _Rationale:_ invalid states must not leak into checked Core IR. _Rejected:_ progressively annotated global AST.
- **Q:** Preserve delimiters as nodes? **A:** Preserve full spans and token stream separately, not every delimiter field initially. _Rationale:_ formatter can consume tokens; semantic syntax stays readable. _Rejected:_ fully concrete syntax tree everywhere; lossy AST alone.
- **Q:** Should `null` be absent because safe code rejects it? **A:** Keep the syntax node so semantic analysis issues the correct context diagnostic. _Rationale:_ lexer/parser should not apply unsafe-context meaning. _Rejected:_ parse failure for contextual semantic rule.

## Variants

- A dedicated concrete syntax tree may later sit beside this semantic surface AST if formatter/refactor needs outgrow the lossless token stream.

## Referenced by

[[src/Pudu/Frontend/_MOC]] · [[src/Pudu/Frontend/Syntax/_MOC]] · [[Frontend]] · [[Pudu Program]]
