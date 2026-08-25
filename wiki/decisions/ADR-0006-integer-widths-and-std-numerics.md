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

**An implementation is a global fact, not an imported one.** Obligations are discharged against every
implementation in the program rather than only those from directly imported modules. Names still come
from imports — a name has to be imported to be written — but a bound is about a type and a trait, and
scoping implementations made a bounded generic unusable across modules: `Std.List.sum` is bounded by
`Add`, whose implementations live in `Std.Num`, and a caller importing only `Std.List` was told
`Int does not implement Add` about a program in which it plainly does.

**A prefix operator binds tighter than every binary one.** `*a * *b` parsed as `*(a * (*b))` — a
dereference of a product rather than a product of two dereferences — which made a `Mul`
implementation impossible to write.

**A shift's count is a plain count.** It answers "how far", which is the same question whatever the
value's width is; requiring the two operands to match would mean writing `1u8 << 3u8` and would make
a generic shift over the integer family impossible.

## What `Std` promises about numbers

The numeric and bitwise surface is **generic, bounded by traits**, and the traits are written:

| Trait | Module | Implemented for |
|---|---|---|
| `Eq`, `Ord` | `Std.Order` | every integer width, both floating widths, `Str`, `Char`, `Bool` |
| `Zero`, `One`, `Add`, `Sub`, `Mul`, `Div` | `Std.Num` | every integer width, both floating widths |
| `Bits` | `Std.Bits` | every integer width; **not** `BigInt`, which has no width |

`Std.Bits` no longer claims sixty-four positions. `width` is a method, so a value answers for its
own: `countLeadingZeros(1u8)` is 7 and `countLeadingZeros(1u32)` is 31.

`Std.List`'s aggregates follow the same bounds. `sum`, `product`, `minimum`, `maximum`, and `sorted`
are generic; `sum` and `product` answer with `Option` because an empty collection has no sum, and
`sumOr` takes the value a caller wants for empty. That is a pre-1.0 signature change and the fixtures
moved with it.

Two rules that shaped the work and still hold:

- **`Std` never converts to `Int` internally to make a signature fit.** That would hide the
  narrowness rather than record it, and would lose signedness and width at the boundary.
- **A bound belongs to the library, not the caller.** `Std.Bits` carries `noBits` and `lowBit` on its
  own trait rather than borrowing `Zero` and `One`, so calling `popCount` needs one import.

## The audit

Every `Int` in a public `Std` signature, classified. An `Int` is **correct** where it names a
position, a count, or a quantity the language itself defines; it is **wrong** where it names a value
the caller chose the type of.

| Module | `Int` in public signatures | Verdict |
|---|---|---|
| `Std.Math` | all 25 were arithmetic on a caller's value | **generalised** — every one is now bounded |
| `Std.List` | `insertOrdered`, `sortOn`, `minimumOn`, `maximumOn` | **generalised** — a key may be any ordered type |
| `Std.List` | `length`, `take`, `drop`, `slice`, `indexOf`, `count`, positions, limits | correct — a length is a count, not a value |
| `Std.Bits` | `places`, `position`, `keep`, `from`/`to`, and the results of `width`, `popCount`, `countLeadingZeros` | correct — every one is a bit *position*, which is a count whatever the value's width is |
| `Std.Text` | lengths, indices, widths, counts | correct |
| `Std.Char` | scalar values and digit values | correct — a scalar value is defined by Unicode, not by the caller |
| `Std.Time` | milliseconds, calendar fields, zone offsets | correct — the units are the library's own |
| `Std.Http` | status codes, content lengths, ports | correct — the protocol defines them |
| `Std.Json`, `Std.Url`, `Std.Map`, `Std.Set`, `Std.Env`, `Std.Process`, `Std.Show`, `Std.Bool`, `Std.Function`, `Std.Order` | positions, sizes, statuses | correct |

`Std.List.range(from, to) -> Array[Int]` stays `Int`: it produces a range of *positions*, and a
caller wanting values of another type maps over it.

## Still missing

**Conversion between integer types** is `convertInteger(value, example)`, a prelude value answering
`Option` of the example's type. It is the one integer operation that cannot be written in Pudu at
all: every other one is arithmetic within a single type, and this one is the boundary between two.

The target type comes from an example value because an expression has no way to name a type. That is
a real limitation of the language rather than a choice, and it is why the shape reads oddly —
`convertInteger(300, 0u8)` rather than `convertInteger[UInt8](300)`. A way to name a type in an
expression would fix it, and is not in this ADR's scope.

`None` rather than truncation, for the same reason checked arithmetic reports rather than wraps. A
caller who wants the low bits masks before converting.

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
