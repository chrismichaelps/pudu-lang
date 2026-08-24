---
type: module
path: "@root/src/Pudu/Type/Check/Rule.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.5
depth_status: MEDIUM
coupling: 3.0
interface_stability: 0.8
tags: [module, medium]
aliases: [Type Check Rule]
---

# Type Check Rule

## Purpose

Own the closed operator, call, member, and index rules for [[Type Check]].

### Governance

- `Str` carries a closed set of built-in methods, typed exactly, for the same reason `Array` does:
  a method whose semantics the compiler knows can be given a precise type, and an unknown one is
  reported rather than dispatched.
- Every text method answers with a **new** value rather than changing its receiver. That is why
  `Str` needs no mutable form, and why the same `W3002` that catches a discarded array result
  catches a discarded text one.
- `indexOf` answers `-1` for absent rather than `Option[Int]`, matching the array method of the
  same name. One vocabulary answering two ways would be worse than either answer; `Std.Text.find`
  provides the `Option` form for callers who want to match on it.

- Indexing follows a borrow rather than rejecting it. Every language with both reads through a
  reference, and requiring `(*items)[0]` would make every function taking `&Array[T]` — which is
  every function that does not want to copy one — read worse than the version that copies. The
  borrow's own mutability is unchanged by reading through it.

- Every rule is the one [[grammar/pudu]] states for that construct; nothing here invents a coercion the language does not have.
- A name is instantiated at every use, so a declared generic serves several types without leaking one use's solution into another.
- A shape the rules cannot type produces a diagnostic naming the type it found, never a silent error type without explanation.
- These rules never recurse into sub-expressions; the walk in [[Type Check]] owns that, which is what keeps the two modules free of a cycle.
- Qualified value paths are looked up in full rather than by final segment. Trait and concrete-receiver method lookup use canonical `NominalId` keys, keeping same-basename declarations in different modules distinct.
- `qualifiedMemberType` recognizes the parser's module-dot-value shape and instantiates the full qualified binding before ordinary field/method dispatch. `enclosingReturnType` reads the current function signature, and `tryType` owns the closed `Result` propagation rule.
- `callType` normalizes an asynchronous function's already formed surface result into `Task[success, failure]`: `Result[S, E]` supplies both channels and every other `T` becomes `Task[T, Never]`. [[Type Check]] requires complete async signatures before this closed rule is reached. `awaitType` accepts only a `Task`, yields its success channel, and routes a non-`Never` failure through the enclosing async function's `Result` declaration.
- `literalType` decodes integer text through [[Integer Literal]] and registers a deferred checker constraint instead of returning hard-coded `Int`. Unary negation updates that constraint's mathematical value before fit checking, so `-128i8` is admitted while `-129i8` and `-1u8` are rejected.
- Prefix `*` reads through a borrow: `*r` has the referent's type when `r` is `&T` or `&mut T`, an unsolved operand is constrained to a shared reference, and anything else reports `E3020`. There is no implicit conversion in either direction, because [[architecture/SEMANTICS]] admits no general subtyping in v1.
- Floating text decodes through [[Float Literal]]. Unsuffixed/`f64` values are `Float64`, `f32` is `Float32`, and overflow reports `E3019` before an infinity can enter evaluation; no contextual narrowing is invented.

### Linkage

- **Requires:** [[Float Literal]], [[Integer Literal]], [[Type Env]], [[Type Unify]], [[Type Value]], [[Syntax Tree]].
- **Consumed by:** [[Type Check]].

## Algorithm

Dispatch on the operator, the receiver's type, or the pattern's shape, unifying against what the construct requires. A `NominalType "Array" [element]` receiver routes to `arrayMethodType`, which returns the function type for each built-in array method (`length`, `get`, `indexOf`, `contains`, `push`, `pop`, `insert`, `remove`, `slice`, `reverse`, `map`, `filter`, `reduce`), threading the element type through higher-order methods so `map` and `filter` type-check correctly.

## Negative Logic (Prohibited Paths)

- No expression recursion, no trait lookup, no numeric promotion, and no exhaustiveness reasoning. Literal fitting is a constraint owned by [[Type Env]], not an implicit conversion.

## Edge Cases

- An unsolved receiver produces a fresh variable rather than a diagnostic, so a member access on a not-yet-known type is not prematurely rejected.
- When two or more trait bounds provide the same member on a rigid receiver, the call is ambiguous and reports `E3013` rather than silently picking the first trait.
- An array method on a `NominalType "Array" [element]` receiver returns the method's built-in function type without consulting the trait or declaration table, because array methods are wired into the evaluator, not declared in user code. An unrecognized method name reports `E3005`.
- `.await` outside an async function reports `E3016`; `.await` applied to a non-task reports `E3017`. A failing task awaited in a function without a compatible `Result` carrier uses the existing failure-propagation `E3011` contract.
- A finite float spelling that converts to infinity at its selected width reports `E3019` at the literal with help to choose a wider type or smaller value.

## Depth

DEPTH 0.50 (MEDIUM). It isolates the closed rules from the walk that applies them.

## Grill Log

- **Q:** Why not inline these into the walk? **A:** The walk would exceed the reviewable size, and these rules are the part a reader checks against the grammar. _Rationale:_ they are a table, and a table is easier to audit alone. _Rejected:_ inlining; a generic operator-table abstraction.
- **Q:** Nest an async `Result[S, E]` as `Task[Result[S, E], Never]`? **A:** No; normalize it to `Task[S, E]`. _Rationale:_ the failure channel is part of the task contract and `.await` propagates it exactly once. _Rejected:_ nested carriers; erasing the failure as `Never`.
- **Q:** Should `callType` guess channels for an unresolved async result variable? **A:** No; async declarations are complete contracts before calls are typed. _Rationale:_ a later `Result[S, E]` solution cannot retroactively split a previously guessed `Task[result, Never]`. _Rejected:_ declaration-order-dependent normalization; deferred ad-hoc rewriting.
- **Q:** Give every integer literal `Int` here? **A:** No; register a fresh literal variable and let context solve it. _Rationale:_ the checker must admit every declared width without inventing conversions, and only the constraint finalizer has both the selected type and mathematical value. _Rejected:_ eager `Int`; numeric widening hidden in unification.
- **Q:** Defer floats like integers? **A:** No; unsuffixed float syntax is explicitly `Float64` and `f32` is the visible narrowing operation. _Rationale:_ unlike exact integers, a decimal-to-binary conversion already chooses precision and can lose information. _Rejected:_ contextual `Float32`; silently narrowing an unsuffixed literal.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Check]]
