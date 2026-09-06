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

The exported signatures are the module header's export list; [[Evaluator]] is the only consumer, and every function here is total with respect to the values the earlier phases admit. `nominalNameOf` gives the evaluator the same runtime owner used by ordinary method lookup, including the exact integer kind and floating width.

### Governance

- A member on a **variant** is looked for on the sum that owns it before the variant itself. An implementation is written for the type — `impl Named for Option[Int]` — and the value in hand is one of its variants, so looking only at the variant found nothing and reported a type the reader never wrote. The variant's own name is still tried after, so a member keyed there keeps working.
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
- Trait-qualified dispatch uses that same nominal owner. A scalar is not excluded merely because it
  has no record constructor: `Integer.fromBigInt(&0u8, value)` must select the `UInt8`
  implementation exactly as `0u8.fromBigInt(value)` does.

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

- **Q:** Why look at the owning sum before the variant? **A:** Because that is where an
  implementation is written. _Rationale:_ `impl Named for Option[Int]` keys under `Option`, and the
  value reaching dispatch is a `Some`; consulting only the variant made the checker and the
  evaluator disagree about the same program, and the error named `a Some`, which the reader never
  wrote. _Rejected:_ refusing the implementation at declaration time, which would close the
  disagreement by removing a capability rather than by supplying it.
- **Q:** Why still try the variant afterwards? **A:** So nothing that worked stops working.
  _Rationale:_ a member keyed on a variant name resolves as it did, and the sum is only preferred
  where both exist. _Rejected:_ replacing the lookup outright.

- **Q:** Why a separate module rather than more of [[Evaluator]]? **A:** Because the walker would pass 500 lines and stop being reviewable. _Rationale:_ the split follows a real seam — values, environment, matching, and operators are independently testable. _Rejected:_ one large evaluator file.
- **Q:** Round only `Float32` literals? **A:** No; normalize each arithmetic result too. _Rationale:_ binary32 precision applies to operations, not just source conversion. _Rejected:_ hidden binary64 intermediates; rounding only when a value is printed.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Evaluator]]

## Shared scalar bounds

`integerKindBounds` supplies the inclusive mathematical interval of a bounded kind, or Nothing
for BigInt. Checked arithmetic, literal fit checks and saturation share these intervals. Admitted
signed widths use constant interval pairs; unsigned widths reuse the existing masks. Platform kinds
resolve through targetPointerWidth. No host-width narrowing or change to overflow behavior occurs.

### Resolved Grill Log
- **Q:** Recompute powers independently in checked and saturating operations? **A:** No; share the width descriptor.
- **Q:** Give BigInt artificial machine bounds? **A:** No; Nothing denotes its unbounded interval.

## Native modular arithmetic

Wrapping add/subtract/multiply for widths 1..64 operate on Word64 carriers before reinterpretation
at the declared width. Reduction modulo 2^64 followed by reduction modulo 2^w equals direct
reduction modulo 2^w for these three operations when w <= 64. This also preserves signed results
through the existing wrapping conversion. Wider kinds and BigInt retain mathematical Integer
operations; checked and saturating operations remain on their exact-result paths.

### Resolved Grill Log
- **Q:** Build an arbitrary-precision product only to discard its high bits? **A:** No; bounded modular multiplication computes only the carrier bits needed.
- **Q:** Extend modular reduction to division? **A:** No; the reduction law does not justify that transformation.

## Native bitwise kernels

Fixed-width AND, OR, XOR and complement use Word64 carriers for widths through 64 bits and then
reinterpret the result at its declared width. Wider types and BigInt retain Integer operations.
Only the existing bitwise operators consume these internal kernels. Platform kinds retain their
target width; this introduces no implicit surface conversion or raw-pointer access.

### Resolved Grill Log
- **Q:** Lose signed interpretation in an unsigned carrier? **A:** No; the existing declared-kind wrapping conversion restores it after the operation.
- **Q:** Give BigInt a finite complement? **A:** No; its Integer fallback retains unbounded two's-complement behavior.

## Native bounded shifts

After existing shift-count validation, widths through 64 use Word64 left shifts and unsigned
right shifts. Signed right shifts use Int64 only when the original mathematical value fits that
carrier; otherwise they retain exact Integer shifting. Unsigned right shifts first reduce to the
declared width so bits above it cannot enter the result. Wider widths retain Integer operations.
The helper defensively falls back outside native shift-count bounds. Public count diagnostics and
BigInt dispatch are unchanged.

### Resolved Grill Log
- **Q:** Right-shift an unmasked wide unsigned operand? **A:** No; normalize to its declared bit pattern first.
- **Q:** Use logical shifting for signed values? **A:** No; use an arithmetic signed carrier or the exact fallback.
