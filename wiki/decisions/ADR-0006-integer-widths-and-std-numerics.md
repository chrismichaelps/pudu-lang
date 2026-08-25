---
type: decision
status: Accepted
date: 2026-08-24
tags: [decision, numerics, stdlib]
aliases: [ADR-0006, Integer Widths and Std Numerics]
---

# ADR-0006 — Integer widths at run time, and what `Std` promises about numbers

## Context

[[architecture/SEMANTICS]] has always said what integers are: two's-complement, `Int` and `UInt` at
the target's pointer width, checked fixed-width arithmetic yielding the exact result or a typed
overflow failure, wrapping and saturating operators as *separate* operations, and shifts requiring a
count below the bit width.

The implementation did none of it. Every integer was an arbitrary-precision value with no width, so:

| Written | Answered | Should answer |
|---|---|---|
| `~0u8` | `-1` | `255` |
| `255u8 + 1u8` | `256` | overflow |
| `255u8 &+ 1u8` | `256` | `0` |
| `250u8 +| 10u8` | `260` | `255` |
| `1u8 << 9` | `512` | refused |
| `200u8 >> 1` | `100` | `100` (by luck; a negative pattern would not be) |

`UInt8` was a compile-time fiction: the checker validated that a *literal* fit, and the runtime then
carried whatever the arithmetic produced. A value's type said one thing and the value was another.

This is also what made the standard library's numeric surface dishonest. `Std.Bits` documented "the
low sixty-four positions" while its parameter type was `Int` — whose width is the target's, not
sixty-four — and every numeric helper in `Std.List` was fixed to `Array[Int]` because there was no
way to be honest about anything else.

A second defect blocked the repair. An `impl Ord for Int` type-checked and then failed at run time
with "cannot read before from a integer": the evaluator dispatched methods on records and variants
only, and `Self` did not alias in an implementation for a wired-in type. So the trait-bounded design
the standard library needs could not be written at all.

## Decision

**A value carries its integer kind, as a float already carries its width.**

`IntValue` becomes `IntValue !IntegerKind !Integer`, mirroring `FloatValue !FloatWidth !Double`.
`IntegerKind` distinguishes each fixed width, `Int` and `UInt` as their own kinds rather than as the
target's width written out, and `BigInt` as the one with no width at all.

`Int` and `Int64` stay distinct kinds even when the target makes them the same size. They are
distinct types, and an implementation for one is not an implementation for the other.

**The three arithmetic families stop being the same operation.** Checked `+ - *` produce the exact
result or `E7005` naming the type that could not hold it. Wrapping `&+ &- &*` reduce into the type's
interval. Saturating `+| -| *|` clamp to its ends.

**Bitwise operations are taken over the type's own width.** Complement, `and`, `or`, and `xor` mask
to it. A right shift keeps the sign on a signed type and does not on an unsigned one. A shift count
that is negative or not below the width is `E7004`, as the vault's checked form requires.

**When two operands have different kinds, the specific one wins.** The language admits no implicit
numeric conversion, so in a program that type-checks both operands of an operator have the same
type. Seeing two kinds therefore means one came from a literal the checker resolved to the other —
an unsuffixed `200` written where a `UInt8` was wanted. This is exact rather than a guess: it is
only ever reached for a program the checker already agreed about.

**Implementations reach wired-in types.** A built-in method vocabulary that does not hold a name
falls through to the type's own implementations, and `Self` aliases to a wired-in target. `impl Ord
for Int` now works, which is the prerequisite for everything below.

## What `Std` promises about numbers

**Target:** the numeric and bitwise surface is generic, bounded by traits — `Eq`, `Ord` for
comparison; `Zero`, `Add` for aggregation; `Bits` for the bitwise family, with the width taken from
the type rather than assumed. Implementations for the whole integer family.

**Now:** the runtime work above is done, so those traits can be written; they are the next slice.
Until they land, the numeric helpers in `Std.List` and the whole of `Std.Bits` remain `Int`-only and
are marked provisional in their own documentation. Two rules hold in the meantime:

- **No new `Int`-only numeric API is added.** The interim surface does not grow.
- **`Std` never converts to `Int` internally to make a signature fit.** That would hide the
  narrowness rather than record it, and would lose signedness and width at the boundary.

`Std.Bits` no longer claims sixty-four positions; it asks the value.

## Consequences

- `UInt8` and the rest are real types at run time. A program that overflows one is told so.
- Pre-1.0 breaking: a program that relied on `255u8 + 1u8` answering `256` now gets a diagnostic.
  That program was wrong, and silently.
- Three test expectations changed from a value to a diagnostic, which is the change working.
- The evaluator now knows a little about types — the width of an integer. It does not know anything
  else, and does not consult the checker; the kind travels with the value.

## Alternatives rejected

- **Keep integers unbounded and check only literals.** This is what existed. It makes every
  fixed-width type a comment.
- **Have the evaluator consult `TypeInfo` for each literal's resolved type.** Exact, but it makes
  the evaluator depend on the checker for ordinary evaluation, and the kind-meet rule above is
  already exact for every program that type-checks.
- **Widen every `Std` numeric API to `BigInt`.** Loses width and signedness at the boundary, which
  is the opposite of what a systems language's standard library should do.
- **Per-width modules (`Std.Bits.UInt64`) as the end state.** Thirteen copies of one module, each
  drifting. Acceptable only as a stopgap, and the trait path removes the need for one.

## Referenced by

[[architecture/SEMANTICS]] · [[architecture/STDLIB]] · [[Eval Operator]] · [[Integer Literal]]
