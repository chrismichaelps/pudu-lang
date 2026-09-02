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

Own runtime values, including retained floating precision, builtin functions, and the total order the keyed collections are held in. How a value prints belongs to [[Eval Render]].

## Interface

The exported signatures are the module header's export list; [[Evaluator]] is the only consumer, and every function here is total with respect to the values the earlier phases admit. `ArrayValue` wraps a `Data.Sequence.Seq Value` from `containers`, giving O(1) append and O(log n) index access with structural sharing for immutable updates. `MapValue` and `SetValue` wrap `Data.Map.Strict` and `Data.Set` keyed by `OrdValue`, giving the same structural sharing and O(log n) lookup and insertion; [[Eval Keyed]] holds their semantics. `TaskValue` retains a closure plus its already-evaluated argument bindings so calling an async function does not run its body.

### Governance

- Data and mechanics only: nothing here decides program meaning that [[architecture/SEMANTICS]] assigns to another phase.
- Failures are reported as `E7xxx` diagnostics through [[Eval Env]], never as host exceptions or partial values.
- Every operation is defined for the value shapes the evaluator can produce, and says so explicitly for the shapes it cannot.
- `FloatValue` carries [[Float Literal]]'s `FloatWidth` beside its normalized `Double` storage. The tag is semantic: equality and operators cannot erase whether the admitted value is binary32 or binary64.
- A closure is equal to another when it is the same closure: same name, same receiver, same function. What it captured is deliberately not compared, because a captured environment reaches the scope the closure was made in, and that scope holds the closure — so a comparison that followed captures would not end. Equality on closures exists to answer identity, which is what removing one from a list of the tasks a scope started is asking.
- `OrdValue` and `compareValues` are declared here, not in [[Eval Order]], because `MapValue` and `SetValue` are keyed by that order and the value type cannot be declared without it. `Value` itself still has no `Ord` instance: a function is a value and no order on functions is meaningful, so the wrapper keeps every keyed use visible.

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
- **Q:** Why did #157 move the order into this module rather than leave it beside `comparableValue`? **A:** Because the keyed constructors now name it. A map keyed by a balanced tree cannot be declared before the order that tree is arranged by, and declaring the instance in [[Eval Order]] would make it an orphan, which [[grammar/haskell]] prohibits. _Rejected:_ an `.hs-boot` cycle, which preserves the old file boundary at the price of a build-order subtlety every later reader has to learn.
- **Q:** Does moving the order in push this file past the size the delivery rules allow? **A:** It did — 522 lines, measured rather than estimated — so rendering moved out to [[Eval Render]] and the file came back to 452. _Rationale:_ the seam was already there and is a real one: how a value prints is not what a value is, and the printing had no reader inside this module. _Rejected:_ leaving the file over the limit on the grounds that the excess was small, and splitting the order back out instead, which the constructors no longer allow.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Evaluator]]
