---
type: architecture
aliases: [Native Unsigned Integers]
tags: [native, numeric, architecture]
---
# Native Unsigned Integers

## Admission and representation

Admit canonical UInt and UInt8/16/32/64 through nativeIntegerKind, preserving
PlatformUnsigned versus UnsignedKind 64 identity. Only compiler-wired unowned
nominal identities without arguments select an integer kind. Reuse revision-5
exact carriers and heap frames; no signed C narrowing or new ABI is permitted.
UInt64's upper half retains a nonnegative sign flag and its full uint64_t bits.
Aliases, selected unsuffixed literals, suffixes, locals, arguments, results,
branches and loop transfers preserve that value before an operation settles it.

## Operations and boundaries

Reuse checked mathematical kernels with bounds [0, 2^width-1]. Underflow and
nonzero unary negation produce the declared kind's E7005; negating zero is zero.
Wrapping reduces modulo 2^width and saturation clamps to zero or the maximum.
Bitwise/complement results decode without sign extension. Right shifts are
logical even when the high bit is set. Counts remain platform Int and must be
nonnegative and below the left width; both effects precede the existing E7004.
Comparisons use exact nonnegative magnitudes. Division/remainder reject zero;
all other full-width quotients/remainders use unsigned magnitude arithmetic.
UInt entry results follow the existing IntValue status policy, including 255
for values above 255. No change to ordinary checking or evaluator semantics.

The current literal guard is safe only behind successful ordinary checking;
it must not legalize a negative unsigned source literal. Probe static rejection
and runtime negation separately. Int128, UInt128, BigInt, floats and Decimal
remain future requirements; numeric and full-language coverage stay incomplete.

## Evidence and ownership

Compiler Engineer owns Lower.Types admission. Test Engineer owns the unsigned
mathematical corpus and canonical/refusal/entry tests plus registration. Reuse
runtime helpers unless evidence exposes a defect and its mirror is resolved.
Require independent Integer answers at all endpoints and high-bit values,
checked failures, wrapping/saturation, comparisons, shifts, selected literals,
aliases/inference, mutation, Never, loop bounds and entry statuses. Compare
both evaluators and actual native code under strict C11 and sanitizers. Full
repository gates and independent reviews precede promotion. No subagents execute.

## Resolved Grill Log

- **Q:** Interpret UInt64's high bit as a sign? **A:** No; actual sign and bits are distinct in the existing carrier.
- **Q:** Add a new C calling convention? **A:** No; the existing integer cell preserves the complete domain.
- **Q:** Wrap checked subtraction or negation? **A:** No; underflow uses the existing width-specific overflow diagnostic.
- **Q:** Accept negative literals because the carrier can hold them? **A:** No; source checking remains authoritative.
- **Q:** Count this as complete numeric coverage? **A:** No; wider and noninteger families remain explicit.

## Dependencies and consumers

[[Compiler Lower Types]] · [[Native Signed Integers]] · [[Exact Native Integer Carriers]] · [[Native Execution Frames]]

## Referenced by

[[architecture/_MOC]] · [[Native Unsigned Integer Delivery]] · [[Native Emission Coverage]]
