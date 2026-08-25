---
type: module
path: "@root/src/Pudu/Eval/Operator.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.45
depth_status: MEDIUM
coupling: 2.0
interface_stability: 0.8
tags: [module, medium]
aliases: [Eval Operator]
---

# Eval Operator

## Purpose

Own operator and access semantics for [[Evaluator]]. `readIndex` handles tuples, strings, and arrays; `readMember` dispatches fields and methods including the full array accessor method table (42 methods: core accessors, mutation, higher-order, construction, aggregation, ordering, and transformation).

## Interface

The exported signatures are the module header's export list; [[Evaluator]] is the only consumer, and every function here is total with respect to the values the earlier phases admit.

### Governance

- An integer carries its kind, as a float carries its width. The type says `UInt8` and the value has
  to agree, or the type said nothing: without a width, `~0u8` answers `-1` and `255u8 + 1u8` answers
  `256`, neither of which is a value those types have. See
  [[decisions/ADR-0006-integer-widths-and-std-numerics]].
- Checked, wrapping, and saturating arithmetic are **three different operations**. They were all
  plain addition, so a program asking for one of the three got whichever the machine's integers
  happened to do. Checked reports `E7005` naming the type; wrapping reduces into its interval;
  saturating clamps to its ends.
- Bitwise operations are taken over the type's own width, and a right shift keeps the sign only on a
  signed type. A shift count that is negative or not below the width is `E7004`, which is the
  checked form the vault requires.
- When two operands carry different kinds, the specific one wins over the platform default. The
  language admits no implicit numeric conversion, so both operands of a well-typed operator have the
  same type; two kinds means one came from a literal the checker resolved to the other. It is exact,
  not a guess.
- A built-in method vocabulary that does not hold a name **falls through to the type's own
  implementations**, so `impl Ord for Int` is reachable. Without it, every trait-bounded generic was
  unusable for the types a program actually holds.

- Text methods are built into the evaluator rather than written in `Std`, because implementing them
  in the language would need `unsafe` to reach the representation — and a standard library that
  needs unsafe for `toUpper` has said something false about the language.

- Borrowing and dereferencing are identities at run time: a reference is the value it refers to, and only typing distinguishes them. The distinction becomes observable when ownership checking and a store exist.

- Data and mechanics only: nothing here decides program meaning that [[architecture/SEMANTICS]] assigns to another phase.
- Failures are reported as `E7xxx` diagnostics through [[Eval Env]], never as host exceptions or partial values.
- Every operation is defined for the value shapes the evaluator can produce, and says so explicitly for the shapes it cannot.
- Float operations require equal retained widths and normalize every arithmetic result through [[Float Literal]]. Comparisons preserve IEEE host behavior at the already-normalized operands.

### Linkage

- **Requires:** [[Float Literal]], [[Eval Value]], [[Syntax Tree]], [[Diagnostic Model]].
- **Consumed by:** [[Evaluator]].

## Algorithm

Direct structural recursion over the value or syntax shape; no caching, no mutation, no reflection.

## Negative Logic (Prohibited Paths)

- No typing, coercion, dispatch, IO, or ownership behaviour.

## Edge Cases

- A shape this module cannot handle produces a diagnostic naming the shape, never a default value.
- A binary32 addition such as `16777216.0f32 + 1.0f32` remains `16777216.0`; retaining a binary64 intermediate would violate the runtime width.

## Depth

DEPTH 0.45 (MEDIUM). It keeps one concern out of [[Evaluator]], which would otherwise exceed the size the delivery rules allow.

## Grill Log

- **Q:** Why a separate module rather than more of [[Evaluator]]? **A:** Because the walker would pass 500 lines and stop being reviewable. _Rationale:_ the split follows a real seam — values, environment, matching, and operators are independently testable. _Rejected:_ one large evaluator file.
- **Q:** Round only `Float32` literals? **A:** No; normalize each arithmetic result too. _Rationale:_ binary32 precision applies to operations, not just source conversion. _Rejected:_ hidden binary64 intermediates; rounding only when a value is printed.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Evaluator]]
