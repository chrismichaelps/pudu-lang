---
type: module
path: "@root/src/Pudu/Eval/Program.hs"
fidelity: Active
domain: "[[Execution Result]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.45
depth_status: MEDIUM
coupling: 3.0
interface_stability: 0.85
tags: [module, medium, runtime]
aliases: [Eval Program]
---

# Eval Program

## Purpose

Run a program, fold a module's constants, and link what either depends on.

## Interface

```haskell
evaluateEntryPoint     :: Map Span Text -> Text -> Module -> IO EvalOutcome
evaluateProgramEntry   :: Map Span Text -> [(Text, Module)] -> Text -> Module -> IO EvalOutcome
evaluateProgramTallied :: Map Span Text -> [(Text, Module)] -> Text -> Module -> IO (EvalOutcome, Int)
evaluateModule         :: Map Span Text -> Module -> IO EvalOutcome
```

### Governance

- **This depends on the evaluator rather than the other way round**, so nothing
  here needs a capability record. The recursion the rest of the evaluator
  carries does not reach out this far: a program is run once, and running it
  never asks to run another.
- Each dependency is loaded in a frame of its own and republished under its
  dotted path, and **a module's functions capture the module they were declared
  in**. Without that every module shared one namespace, so the last one linked
  shadowed every earlier one for everybody.
- The root gets a frame of its own, so its declarations shadow a dependency's
  rather than sharing the last one linked.
- What inference settled on for each integer literal is a required argument, not
  a default. A caller that forgot it would get a program whose declared widths
  are not enforced, and nothing would say so.
- Compile-time folding runs the same interpreter with effects refused, which is
  why a `const` that reads a file is stopped at the boundary rather than
  quietly reading it while the compiler runs.

### Linkage

- **Requires:** [[Evaluator]], [[Eval Env]], [[Eval Install]], [[Eval Value]].
- **Consumed by:** [[Compiler Pipeline]], [[Repl Session]], [[Tooling]].

## Algorithm

Link the dependencies, push a frame for the root, install its declarations, look
the entry name up, and call it.

## Negative Logic (Prohibited Paths)

- No expression evaluation of its own — that is [[Evaluator]], which this
  imports.
- No compiling. A module arrives parsed and checked; running something that did
  not compile is what the pipeline refuses before reaching here.

## Grill Log

- **Q:** Why does this not take a capability like the checker's splits do?
  **A:** Because there is no cycle to express. _Rationale:_ every other split in
  this codebase separated two halves of a real recursion, and this one separates
  a surface from the thing it sits on — the dependency runs one way only, so an
  ordinary import states it exactly. _Rejected:_ a record for symmetry with the
  other splits, which would claim a cycle that does not exist.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Evaluator]] · [[Compiler Pipeline]]
