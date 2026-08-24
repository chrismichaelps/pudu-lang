---
type: module
path: "@root/src/Pudu/Eval/Value.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.45
depth_status: MEDIUM
coupling: 2.0
interface_stability: 0.8
tags: [module, medium]
aliases: [Eval Value]
---

# Eval Value

## Purpose

Own runtime values, including retained floating precision, builtin functions, and their rendering for [[Evaluator]].

## Interface

The exported signatures are the module header's export list; [[Evaluator]] is the only consumer, and every function here is total with respect to the values the earlier phases admit. `ArrayValue` wraps a `Data.Sequence.Seq Value` from `containers`, giving O(1) append and O(log n) index access with structural sharing for immutable updates. `TaskValue` retains a closure plus its already-evaluated argument bindings so calling an async function does not run its body.

### Governance

- Data and mechanics only: nothing here decides program meaning that [[architecture/SEMANTICS]] assigns to another phase.
- Failures are reported as `E7xxx` diagnostics through [[Eval Env]], never as host exceptions or partial values.
- Every operation is defined for the value shapes the evaluator can produce, and says so explicitly for the shapes it cannot.
- `FloatValue` carries [[Float Literal]]'s `FloatWidth` beside its normalized `Double` storage. The tag is semantic: equality and operators cannot erase whether the admitted value is binary32 or binary64.

### Linkage

- **Requires:** [[Float Literal]], [[Syntax Tree]], [[Diagnostic Model]].
- **Consumed by:** [[Evaluator]].

## Algorithm

Direct structural recursion over the value or syntax shape; no caching, no mutation, no reflection.

## Negative Logic (Prohibited Paths)

- No typing, coercion, dispatch, IO, or ownership behaviour.

## Edge Cases

- A shape this module cannot handle produces a diagnostic naming the shape, never a default value.
- `BuiltinValue PanicBuiltin` is the prelude's `panic`: calling it stops evaluation with `E7007`, which represents a violated invariant rather than a recoverable domain failure.
- `TaskValue` renders as an opaque task and is not callable as an ordinary function; only `.await` starts its retained closure body.
- Both float widths render their normalized numeric value without a runtime suffix; `:type` remains the source of static width inspection.

## Depth

DEPTH 0.45 (MEDIUM). It keeps one concern out of [[Evaluator]], which would otherwise exceed the size the delivery rules allow.

## Grill Log

- **Q:** Why a separate module rather than more of [[Evaluator]]? **A:** Because the walker would pass 500 lines and stop being reviewable. _Rationale:_ the split follows a real seam — values, environment, matching, and operators are independently testable. _Rejected:_ one large evaluator file.
- **Q:** Store an already computed async result? **A:** No; store the prepared closure and bindings. _Rationale:_ an async call is cold and body evaluation begins at `.await`. _Rejected:_ eager execution wrapped in a task-shaped value; a placeholder unit task.
- **Q:** Erase `Float32` to a host `Double`? **A:** No; pair normalized storage with a width tag. _Rationale:_ later operations must round to binary32 and mixed-width values must not compare equal merely because their storage matches. _Rejected:_ static-only precision; a separate runtime constructor with duplicated rendering logic.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Evaluator]]
