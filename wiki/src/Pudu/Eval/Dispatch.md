---
type: module
path: "@root/src/Pudu/Eval.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.55
depth_status: MEDIUM
coupling: 3.0
interface_stability: 0.7
tags: [module, medium]
aliases: [Eval Dispatch]
---

# Eval Dispatch

## Purpose

Own array method dispatch, keeping the evaluator walker focused on tree traversal. `callArrayMethod` pattern-matches each `ArrayMethod` tag to its arity check and [[Eval Array]] operation. `applyFunction` and `acceptByFunction` are the closure-call callbacks that `map`, `filter`, and `reduce` need to invoke user-supplied functions.

The dispatch currently lives inline in [[Evaluator]] (`src/Pudu/Eval.hs`). Extraction into `src/Pudu/Eval/Dispatch.hs` is planned once the evaluator exceeds the 500-line delivery limit; the callback-based interface described below is the target design that avoids an import cycle.

## Interface

Defines `callArrayMethod`, `applyFunction`, `acceptByFunction`. In the target extraction, each takes an `applyFn` callback (supplied by [[Evaluator]] as `callClosure`) so Dispatch never imports Eval.

### Governance

- Data and mechanics only: nothing here decides program meaning that [[architecture/SEMANTICS]] assigns to another phase.
- Failures are reported as `E7xxx` diagnostics through [[Eval Env]], never as host exceptions or partial values.
- Arity mismatches report `E7003`; domain failures like empty-array access report `E7004`.

### Linkage

- **Requires:** [[Eval Array]], [[Eval Value]], [[Eval Env]], [[Diagnostic Model]].
- **Consumed by:** [[Evaluator]].

## Algorithm

Direct pattern match on the `ArrayMethod` tag. Each branch validates arity, delegates to the pure operation in [[Eval Array]], and applies any callback via `applyFunction`. No caching, no mutation, no reflection.

## Negative Logic (Prohibited Paths)

- No typing, coercion, IO, or ownership behaviour.
- No direct call to `callClosure` in the extracted form — the closure-call capability arrives as a callback parameter.

## Edge Cases

- Methods that access a single element on an empty array report `E7004` rather than returning a default.
- Higher-order methods (`map`, `filter`, `reduce`) propagate any diagnostic from the callback.

## Depth

DEPTH 0.55 (MEDIUM). It keeps 13 array method dispatch arms out of the evaluator's expression walker, which would otherwise exceed the size the delivery rules allow.

## Grill Log

- **Q:** Why a callback parameter instead of importing `callClosure` directly? **A:** Because [[Evaluator]] already imports Dispatch for `callArrayMethod`, and Dispatch importing Eval for `callClosure` would create a cycle. _Rationale:_ the callback breaks the cycle cleanly and keeps Dispatch testable in isolation. _Rejected:_ a typeclass for function application; a `callClosure` re-export; keeping all dispatch in Eval (which would pass 500 lines once more methods arrive).
- **Q:** Why is dispatch still inline in Eval.hs? **A:** Eval.hs is currently 591 lines, and the dispatch section is self-contained. Extraction is warranted once the file grows past the delivery limit or when additional method groups arrive. _Rationale:_ premature extraction would add an import cycle workaround for no size benefit. _Rejected:_ extracting now with a callback shim; extracting now and moving `callClosure` into Dispatch.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Evaluator]]
