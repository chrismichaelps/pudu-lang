---
type: decision
status: Accepted
date: 2026-08-25
tags: [decision, numerics, decimal]
aliases: [ADR-0007, Decimal Precision and Rounding]
---

# ADR-0007 — What `Decimal` is, and when it is allowed to round

## Context

`Decimal` has been a wired-in type name since the first semantics slice, and writing it has been
rejected with `E3022` ever since: *"Decimal is reserved and has no semantics yet."* That rejection
was correct. A decimal type is not a representation choice, it is a *rounding policy*, and admitting
one without stating the policy would have meant inventing rounding behind the reader's back.

The deferral has run out of usefulness. `Decimal` is the type money is written in, and money is what
a large share of real programs are about. [[architecture/STDLIB]] cannot offer a currency surface
while the type underneath it is unusable, and the grammar has been promising the type in its builtin
list the whole time.

The question this ADR answers is narrow and unavoidable: **`Decimal` cannot represent `1/3`. What
happens when a program asks for it?**

## Decision

### Representation

A `Decimal` is an arbitrary-precision signed integer *coefficient* and a non-negative integer
*scale*:

```
value = coefficient × 10 ^ (-scale)
```

`1.50d` is coefficient `150`, scale `2`. Trailing zeros are **significant and preserved**: `1.50d`
and `1.5d` are the same number and are *not* the same value. `1.50d` prints as `1.50`. This matters
because a scale is a statement about precision — a price of `1.50` claims cents, a price of `1.5`
claims tenths — and normalising it away would discard something the writer said on purpose.

Equality follows the number, not the representation: `1.50d == 1.5d` is `true`. Ordering likewise.
Only rendering and scale-reading tell the two apart. This is the one place the type deliberately
distinguishes what it stores from what it compares, because the alternative — making `==` sensitive
to trailing zeros — would make `Decimal` fail the one property every reader assumes of a number.

### Exact operations

Addition, subtraction, multiplication, negation, and comparison are **always exact and never
round**. Each has a result scale determined entirely by its inputs:

| Operation | Result scale |
|---|---|
| `a + b`, `a - b` | `max(scale a, scale b)` |
| `a * b` | `scale a + scale b` |

No precision limit applies. A coefficient grows as far as the arithmetic requires, exactly as
`BigInt` does, and there is no configured context that can silently truncate one. A program that
adds a million prices gets the sum of a million prices.

### Division

Division is where the policy is forced, and this is the decision:

**`a / b` is exact or it is an error.** When the quotient terminates in base ten, division produces
it exactly. When it does not — `1d / 3d` — the operation fails with `E7010` rather than rounding to
some number of digits nobody asked for.

The reasoning is the same one the integer family already follows. Checked arithmetic is the default
and overflow is a typed failure; wrapping and saturating are *separate operators* a writer opts into
by name. Rounding is the decimal analogue of wrapping: a real answer that has been altered to fit.
It should be equally impossible to get by accident.

A program that wants a rounded quotient asks for one:

```pudu
Decimal.divide(a, b, 10, Rounding.HalfEven)   // 10 fractional digits, banker's rounding
```

`divide` never fails on a non-terminating quotient, because the caller has already said what to do
about it.

### Rounding modes

`Rounding` is a closed sum with seven cases: `Up`, `Down`, `Ceiling`, `Floor`, `HalfUp`,
`HalfDown`, `HalfEven`. These are the modes every decimal standard converges on, and offering a
subset would only push programs into writing their own — worse — versions of the missing ones.

`HalfEven` is the recommended default in documentation and is what `Decimal.round` uses when no mode
is given. It is the mode that does not accumulate bias across many roundings, which is the whole
reason a financial total computed one way matches the same total computed another way.

### Literals

A decimal literal is any numeric literal with the closed lowercase suffix `d`: `1.50d`, `0d`,
`-3d`, `1e6d`. The suffix is part of the literal token, matching how `f32`, `f64`, and the integer
width suffixes already work.

There is **no implicit conversion** from `Float64` to `Decimal`, in either direction. `0.1` as a
binary float is not the number `0.1`, and letting it become `0.1d` silently would import exactly the
error `Decimal` exists to avoid. Conversion is explicit and fallible in the direction that can lose
information:

- `Decimal.fromInt(n)` — total, every integer is exactly representable.
- `Decimal.parse(text)` — `Result`, because text can be malformed.
- `Decimal.toFloat64(d)` — total, and documented as lossy.
- `Decimal.toInt(d)` — `Result`, because a fractional part or an out-of-range value has no answer.

## Consequences

- `E3022` is retired. Writing `Decimal` is now ordinary.
- `E7010` is added: a division whose exact quotient does not terminate.
- `Decimal` is not `Copy`-cheap. Its coefficient is arbitrary precision, so a copy may allocate. It
  is still `Copy`, `Send`, and `Sync`, because it owns no resource and has no interior mutability.
- The type is exact, which means it is also *unbounded*. A pathological program can grow a
  coefficient without limit, the same way `BigInt` can. That is the correct trade for a type whose
  entire purpose is not to lie about the value it holds.

## Rejected alternatives

**A fixed 28- or 34-digit context, rounding half-even, like the common decimal libraries.** This is
the mainstream answer and it was the tempting one. It was rejected because a fixed context makes
every operation potentially lossy while *looking* exact, and the loss appears only at a digit count
most readers never think about. The language's whole numeric stance is that a value-altering
operation must be visible in the source, and a context that rounds `a * b` at digit 29 is invisible
by construction.

**Rounding division to the dividend's scale.** Cheaper to explain than a full context, but it makes
`a / b` depend on how `a` happened to be written — `1.00d / 3d` and `1d / 3d` would give different
answers for the same quantity. A rule that turns a formatting choice into a numeric difference is
worse than an error.

**Normalising trailing zeros away.** Would make `1.50d` and `1.5d` indistinguishable and simplify
equality. Rejected because scale carries intent: a monetary amount that says cents should keep
saying cents through a round trip, and a type that quietly reformats it is not usable for the domain
it exists to serve.

**Making `Decimal` a library type over `BigInt`.** Attractive for keeping the compiler small, but
the literal form has to be lexed and typed, and a library type cannot have one. Half the feature
would have lived in the compiler regardless, and splitting it would have put the exactness guarantee
somewhere a user could accidentally replace.

## Referenced by

[[decisions/_MOC]] · [[architecture/SEMANTICS]] · [[architecture/STDLIB]] · [[grammar/pudu]] · [[ADR-0006]]
