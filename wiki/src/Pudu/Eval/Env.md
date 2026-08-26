---
type: module
path: "@root/src/Pudu/Eval/Env.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.45
depth_status: MEDIUM
coupling: 2.0
interface_stability: 0.8
tags: [module, medium]
aliases: [Eval Env]
---

# Eval Env

## Purpose

Own environment frames, control unwinding, and aborts for [[Evaluator]].

## Interface

The exported signatures are the module header's export list; [[Evaluator]] is the only consumer, and every function here is total with respect to the values the earlier phases admit.

### Governance

- The environment carries a frame stack and, separately, the program's implementations. A name is found lexically first and among implementations second. They are separate because their scoping rules are opposite: a function belongs to the module that declared it, and an implementation belongs to the whole program.

- Scope frames record the children a structured scope started, in order. The frame is a stack like the environment's, so a nested scope owns only what it began and a task started outside every scope stays cold — which is what makes a detached task unrepresentable.

- An unwind carries what the transfer needs to find its owner. A break and a continue carry their optional label, so a loop can tell one addressed to it from one meant for a loop further out and re-raise the latter untouched; a break also carries the value its loop will produce, which is unit when none was written.
- Lexical and captured frames are restored on both ordinary completion and control unwind. A `return`, `break`, or `continue` may cross any number of blocks without leaking their bindings into the construct that catches it; captured callbacks likewise restore the caller before forwarding an unwind.
- Data and mechanics only: nothing here decides program meaning that [[architecture/SEMANTICS]] assigns to another phase.
- Failures are reported as `E7xxx` diagnostics through [[Eval Env]], never as host exceptions or partial values.
- Every operation is defined for the value shapes the evaluator can produce, and says so explicitly for the shapes it cannot.

### Linkage

- **Requires:** [[Eval Value]], [[Syntax Tree]], [[Diagnostic Model]].
- **Consumed by:** [[Evaluator]].

## Algorithm

Environment combinators run the nested evaluator directly and normalize both `Done` and `Unwound` outcomes before returning them. Frame cleanup is therefore part of the combinator rather than a monadic continuation that an unwind can skip; there is no caching, mutation, or reflection.

## Negative Logic (Prohibited Paths)

- No typing, coercion, dispatch, IO, or ownership behaviour.

## Edge Cases

- A shape this module cannot handle produces a diagnostic naming the shape, never a default value.
- The call depth limit is 4096, which is high enough for real recursive programs while still preventing stack overflow on infinite recursion.
- Aborts carry no recoverable environment; ordinary results and unwinds retain changes outside the lexical frame being removed.

## Depth

DEPTH 0.45 (MEDIUM). It keeps one concern out of [[Evaluator]], which would otherwise exceed the size the delivery rules allow.

## Grill Log

- **Q:** Why a separate module rather than more of [[Evaluator]]? **A:** Because the walker would pass 500 lines and stop being reviewable. _Rationale:_ the split follows a real seam — values, environment, matching, and operators are independently testable. _Rejected:_ one large evaluator file.
- **Q:** Why not express frame restoration as `push; action; pop` in the evaluator monad? **A:** An unwind deliberately short-circuits monadic continuation, so the `pop` would never run and a block-local binding could change later dispatch. _Rationale:_ `withFrame` and `withCaptured` inspect the nested outcome and restore frames for both completion paths. _Rejected:_ cleanup in an ordinary bind continuation.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Evaluator]]
