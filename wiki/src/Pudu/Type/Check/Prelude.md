---
type: module
path: "@root/src/Pudu/Type/Check/Prelude.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.3
depth_status: SHALLOW
coupling: 2.0
interface_stability: 0.9
tags: [module, shallow]
aliases: [Type Check Prelude]
---

# Type Check Prelude

## Purpose

The names a program has without declaring them: the constructors every program can write, and the signature of every effect the prelude provides.

## Interface

```haskell
declareBuiltinConstructors :: Checker ()
effectSignatures           :: [(Text, Scheme)]
```

### Governance

- **A table rather than a rule.** Nothing here decides anything; it states what the language already has.
- That is why it depends on nothing in checking and nothing in checking reaches back into it — which made this the one cut in the checker that needed no capability at all.
- Every effect answers with `Result[T, Str]` rather than failing, so a missing file is an outcome a caller handles rather than something that stops the program.

### Linkage

- **Requires:** [[Type Env]], [[Type Value]].
- **Consumed by:** [[Type Check Method]].

## Referenced by

[[src/Pudu/_MOC]]
