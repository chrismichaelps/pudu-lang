---
type: module
path: "@root/src/Pudu/Eval/Effect.hs"
fidelity: Active
domain: "[[Execution Result]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.45
depth_status: MEDIUM
coupling: 3.0
interface_stability: 0.85
tags: [module, medium, runtime]
aliases: [Eval Effect]
---

# Eval Effect

## Purpose

Perform the operations that reach outside the program — reading and writing files, the environment,
the clock, subprocesses, the terminal — and refuse them where reaching outside is not allowed.

## Interface

```haskell
effectBuiltins :: [Builtin]
callEffect     :: Span -> Builtin -> [Value] -> Evaluator Value
```

### Governance

- **Every effect answers with `Result[T, Str]` rather than failing.** The language has no
  exceptions, so a missing file is an outcome a caller handles rather than a control transfer it
  cannot see. The failure carries what the operating system said, which is more useful to a
  program's own user than a message this compiler invented.
- **Effects are refused while a constant is folded**, reported as `E7009`. A `const` initialiser
  runs inside the compiler, so reading a file there would make the compiled output depend on the
  machine that compiled it. The refusal names the same reason whichever effect was reached for, so
  a reader learns the rule rather than one instance of it.
- `effectBuiltins` is one list. The evaluator and the checker both read it, so they cannot disagree
  about which names exist, and adding an effect is one edit rather than three.
- Nothing here decides *whether* a function may perform an effect — only whether the current context
  admits one. [[ADR-0009]] proposes moving that decision into the type, where a signature could
  state it; today it is a runtime gate because effects have no static vocabulary.

### Linkage

- **Requires:** [[Eval Value]], [[Eval Env]], [[Eval Io]], [[Eval Clock]], [[Diagnostic Model]].
- **Consumed by:** [[Eval Builtin]].

## Algorithm

Check that the context admits effects, dispatch on the built-in tag, perform the operation through
[[Eval Io]] or [[Eval Clock]], and wrap the outcome as `Ok` or `Err`.

## Negative Logic (Prohibited Paths)

- No host exceptions escape. Every failure becomes a `Result` or an `E7xxx` diagnostic.
- No effect performed during constant folding, on any path.
- No typing decisions.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Eval Builtin]] · [[Evaluator]] · [[ADR-0009]]
