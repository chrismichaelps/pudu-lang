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

Own runtime values, including retained floating precision, foreign bindings and opaque handles,
builtin functions, and the total order the keyed collections are held in. How a value prints
belongs to [[Eval Render]].

## Interface

The exported signatures are the module header's export list; evaluator runtime modules consume this
shared vocabulary, and every function here is total with respect to the values the earlier phases
admit. `Builtin` and `builtinName` are re-exported from [[Eval Builtin Definition]] to preserve the
established import surface. `ArrayValue` wraps a `Data.Sequence.Seq Value` from `containers`, giving
O(1) append and O(log n) index access with structural sharing for immutable updates. `MapValue` and
`SetValue` wrap `Data.Map.Strict` and `Data.Set` keyed by `OrdValue`, giving the same structural
sharing and O(log n) lookup and insertion; [[Eval Keyed]] holds their semantics. `TaskValue` retains
a closure plus its already-evaluated argument bindings so calling an async function does not run its
body.

### Governance

- Data and mechanics only: nothing here decides program meaning that [[architecture/SEMANTICS]] assigns to another phase.
- Failures are reported as `E7xxx` diagnostics through [[Eval Env]], never as host exceptions or partial values.
- Every operation is defined for the value shapes the evaluator can produce, and says so explicitly for the shapes it cannot.
- `FloatValue` carries [[Float Literal]]'s `FloatWidth` beside its normalized `Double` storage. The tag is semantic: equality and operators cannot erase whether the admitted value is binary32 or binary64.
- A closure is equal to another when it is the same closure: same name, same receiver, same function. What it captured is deliberately not compared, because a captured environment reaches the scope the closure was made in, and that scope holds the closure — so a comparison that followed captures would not end. Equality on closures exists to answer identity, which is what removing one from a list of the tasks a scope started is asking.
- `OrdValue` and `compareValues` are declared here, not in [[Eval Order]], because `MapValue` and `SetValue` are keyed by that order and the value type cannot be declared without it. `Value` itself still has no `Ord` instance: a function is a value and no order on functions is meaningful, so the wrapper keeps every keyed use visible.
- Original network builtins and separately named timeout variants remain distinct constructors, so
  adding an operation budget does not change the arity of an existing prelude value.
- `ForeignHandleValue` carries a declared handle name and address. The name is semantic identity;
  the address remains opaque storage and ownership decisions stay in [[Foreign Ownership]]. A
  `ForeignBinding` producer retains the exact declared native release symbol used for teardown.

### Linkage

- **Requires:** [[Eval Builtin Definition]], [[Float Literal]], [[Syntax Tree]], [[Diagnostic Model]].
- **Consumed by:** [[Evaluator]], [[Eval Builtin]], [[Eval Effect]], and the other evaluator runtime
  modules that inspect or construct values.

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
- **Q:** Does moving the order in push this file past the size target? **A:** It did — 522 lines, measured rather than estimated — so rendering moved out to [[Eval Render]]. Later value and builtin growth took the file to 686 lines; the closed tag vocabulary and its name table then moved to [[Eval Builtin Definition]]. Foreign handles then took it to 548, and the built-in method vocabulary moved to [[Eval Method]], leaving 328. Each extraction followed the same seam — a closed tag set and its name table, depending on no runtime value — and each is re-exported here, so no call site learned that anything moved. _Rationale:_ size accounting must describe the current source honestly, and a limit is worth keeping only if the split follows the code rather than the line count. _Rejected:_ claiming an old measurement is current; splitting the file arbitrarily to fit.

## Foreign handle generations

`ForeignHandleValue` carries canonical type, opaque native address, and ownership generation.
Equality includes the generation, so address reuse does not make two ownership lifetimes equal.
The generation is runtime metadata and never crosses the native ABI or becomes a Pudu integer.

### Resolved Grill

- **Q:** Erase claim identity when building a handle value? **A:** No; aliases retain the original
  generation and cannot operate on a replacement object at a reused address.

## Owned and borrowed handles

`ForeignHandleValue` carries a `ForeignClaim`: `OwnedClaim` with the generation the store admitted,
or `BorrowedClaim` for a value the library keeps. A library returns both through one C type — what it
gives away, and its own default font, last error text, or drawing target — and the address does not
say which, so it is carried beside it.

A borrowed handle is claimed by no store, contributes no lease to a call, is released at no teardown,
and is refused before native code if it reaches the release its handle type declared. Equality
includes the claim, so a borrowed handle and an owned one at one address are not the same value.

### Resolved Grill

- **Q:** Mark borrowing with a reserved generation instead of a constructor? **A:** No. A sentinel is
  a value that has to be remembered everywhere it is compared; a constructor makes the two cases
  something the compiler asks about at each use.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Evaluator]]
