---
type: module
path: "@root/src/Pudu/Type/Check/Expression/Control.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.6
depth_status: MEDIUM
coupling: 4.0
interface_stability: 0.8
tags: [module, medium, semantics]
aliases: [Type Check Expression Control]
---

# Type Check Expression Control

## Purpose

Check control flow branches, match arms, lambda functions, captured assignment validity, and loop stack context for expressions.

## Interface

```haskell
checkArms
  :: (Located Expression -> Checker Type)
  -> DeclaredTypes
  -> [(Text, Int)]
  -> Span
  -> Type
  -> [Located MatchArm]
  -> Checker Type

lambdaType
  :: (Located Parameter -> Checker Type)
  -> (Located Block -> Checker Type)
  -> (Located Expression -> Checker Type)
  -> DeclaredTypes
  -> [(Text, Int)]
  -> Function
  -> Checker Type

checkCapturedAssignment :: Text -> Located Expression -> Checker ()

aroundLoop :: Maybe (Located Text) -> Type -> Bool -> Checker a -> Checker Bool

literalIndex :: Located Expression -> Maybe Integer
```

### Governance

- Extracted from `Pudu.Type.Check.Expression` to maintain source files strictly under 500 lines.
- `checkArms` validates arm pattern bindings, arm guards, arm bodies, and unifies all arm results into a single common type while reporting exhaustiveness and redundancy at expression boundaries.
- `lambdaType` verifies closure parameter bindings, closure body evaluation (either block or expression body), and returns a non-generalized `FunctionTypeValue`.
- `checkCapturedAssignment` prohibits assignments to captured variables from outside a closure, enforcing immutable captures.
- `aroundLoop` manages loop context entry and exit on the type environment's loop stack, tracking break statements and carries.
- `literalIndex` parses constant integer expressions for tuple and nominal element index lookups.

### Linkage

- **Requires:** [[Type Env]], [[Type Unify]], [[Type Value]], [[Type Formation]], [[Type Check Pattern]], [[Frontend Syntax Tree]].
- **Consumed by:** [[Type Check Expression]].

## Algorithm

- Match arm checking uses `bindPattern` to introduce arm patterns in a local type scope, unifies guards against boolean type, checks arm bodies, and folds unification over all arm results.
- Lambda typing checks parameters via passed checkers, forms return types, binds `self`, and unifies actual body type with declared or inferred return.

## Negative Logic (Prohibited Paths)

- No direct import of [[Type Check Expression]]; recursive checking is passed via higher-order functions to preserve strict DAG layering.
- No generalisation of lambda signatures; closures are fixed at their introduction point.

## Grill Log

- **Q:** Why pass recursive checkers (`Located Expression -> Checker Type`, etc.) rather than importing `CheckSurroundings` or `Expression`? **A:** Because `Pudu.Type.Check.Expression` imports `Control`. Passing function runners decouples control construct checking from expression coordination and prevents circular imports without `.hs-boot`.
- **Q:** Why group match arms, lambdas, loops, and captured assignments together in `Control`? **A:** These represent the non-trivial control and scope boundaries of expressions (arms, closure scopes, loop labels/carries, and write guards). Moving them leaves `Expression.hs` as a clear, focused AST dispatcher well below 400 lines.

## Referenced by

[[Type Check Expression]] · [[src/Pudu/Type/_MOC]]
