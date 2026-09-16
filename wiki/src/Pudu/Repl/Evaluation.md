---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Repl/Evaluation.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.65
depth_status: MEDIUM
coupling: 4.0
interface_stability: 0.9
tags: [module, repl, runtime]
aliases: [Repl Evaluation]
---

# Repl Evaluation

## Purpose

Select a checked submission block from the synthetic `__session` function and execute
it in `Eval.Context` without replaying previously evaluated statements.

## Interface

### Signatures

```haskell
evaluateEntry
  :: EvaluationContext
  -> Maybe TypeInfo
  -> Bool
  -> Bool
  -> Bool
  -> Int
  -> Int
  -> [(Text, Module)]
  -> CompileResult
  -> (EvalOutcome -> IO ())
  -> IO (Maybe EvalOutcome)

retainedTypes :: CompileResult -> Maybe TypeInfo

declarationUpdateAllowed :: Int -> Int -> CompileResult -> Bool
```

`evaluateEntry` takes retained `TypeInfo`, compatibility flags, bounds (`start`, `width`),
dependency syntax, the `CompileResult`, and an outcome publication callback.
`retainedTypes` filters the compiler type map to expressions wholly contained within
individual local AST statements, excluding the synthetic enclosing `__session` function.
`declarationUpdateAllowed` ensures that only allowed top-level declarations (function
or binding declarations) within the specified region can be updated dynamically.

### Governance

- Prior inferred expression types must remain identical between submissions; fresh inference
  must not reinterpret live values under changed types.
- Only AST nodes strictly within the current submission's span are executed. Nodes crossing
  entry boundaries are rejected with `E7001`.
- Runtime aborts preserve previous environment frames and source; external effects are nontransactional.
- Source publication uses `Eval.Context`'s masked commit callback so runtime state and accepted
  source advance atomically.

### Linkage

- **Requires:** [[Eval Context]], [[Eval Program]], [[Eval Env]], [[Syntax Tree]], [[Type]].
- **Consumed by:** [[Repl Session]].

## Algorithm

1. Verify context compatibility (dependencies and declarations match previous state).
2. Check that retained expression types are a consistent submap of new inferred types.
3. Extract the `__session` function block from the checked AST.
4. Filter statements and result expression to those falling strictly within `[start, start + width]`.
5. Rebuild declaration environment if needed, install integer kinds, and invoke `evaluateInteractiveBlock`.
6. Commit outcome and trigger the publication callback under mask.

## Negative Logic (Prohibited Paths)

- Never replay accumulated prior statements or their side effects during submission evaluation.
- Never execute AST nodes spanning outside the current entry offset range.
- Never treat a missing compile module or missing `__session` body as successful evaluation.

## Grill Log

- **Q:** Why execute only new AST nodes instead of replaying the entire synthetic block?
  **A:** Replaying accumulates duplicate side effects (I/O, allocations, mutations) on every prompt entry.
  Executing only the newly entered statements preserves live bindings while maintaining clean semantics.
- **Q:** How are type safety and redefinition handled across prompts?
  **A:** `retainedTypes` captures inferred types of earlier statements. If an entry alters an earlier
  binding's inferred type or mutates external dependencies incompatibly, it is rejected with `E7001`
  before execution, requiring `:reset` or `:load`.

## Referenced by

[[src/Pudu/Repl/_MOC]] · [[Repl Session]] · [[Pudu REPL]] · [[Eval Context]]
