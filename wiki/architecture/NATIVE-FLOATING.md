---
type: architecture
aliases: [Native Floating Point]
tags: [native, numeric, conformance]
---
# Native Floating Point

## Required observations

Native Float32/Float64 must preserve the existing evaluator, not a replacement
floating-point policy. FloatLiteral normalizes Float32 to binary32 and widens it
for Double storage. Eval.Operator performs each arithmetic operation on those
Double values, then normalizes the result to the selected width. Negation keeps
negative zero. Division by zero yields IEEE infinities/NaN; comparisons use the
ordinary floating predicates. Accepted unsupported operators retain E7001 after
ordered operand effects. NaN equality is false, inequality is true, and all
ordered predicates are false; do not reuse an integer three-way comparator.
Source finite overflow remains E3019. Canonical formed
identities, aliases, ordered snapshots, transfers, calls and cleanup still apply.

Eval.Render prints show Double for both widths. Therefore Float32 display uses
the full widened value, not a shorter binary32 spelling. Preserve NaN, Infinity,
-Infinity, -0.0, mandatory fractional digits, exponent signs and the exact
fixed/exponent threshold. Entry floats render a value and exit zero, unlike
integer entry statuses. Printing must preserve the shared closed-pipe policy.

Floating literal transport must preserve the already parsed binary64 encoding,
including normalized Float32 values. Avoid a second C decimal-literal conversion.
A future floating cell may carry those bits directly; that representation and
its typed arithmetic need separate Core/frame contracts before admission.

## Exact formatting boundary

The locked GHC 9.14.1 GHC.Internal.Float source is installed with the toolchain.
Its formatRealFloatAlt FFGeneric Nothing selects exponent notation when the
returned decimal exponent is below zero or above seven; show uses exponent e-1.
floatToDigits uses Burger/Dybvig rational margins and strict stopping conditions.
A merely round-tripping libc/Ryu spelling is insufficient evidence of equal bytes.
Retain the locked algorithm's exact decisions, with its attribution/license for
any adapted implementation. Verify raw binary64 inputs against installed GHC
show, including signed zeros, subnormals, normal exponent transitions, extrema,
NaN signs/payloads and deterministic full-width samples.

The conversion's temporary integers are bounded by the binary64 domain; they
are not Pudu BigInt. A private 40-limb base-2^32 natural provides 1280 bits.
Raw initial numerators/denominators fit at most 1077 bits; even a loose bound
combining a 54-bit numerator with 10^323 and 24 decimal generation steps stays
below 1210 bits. Refine/check this bound against the actual formatter before
admission. Capacity failures are checked internal invariant failures, never
silent truncation or a smaller accepted floating domain.

## Delivery sequence and ownership

First implement and independently test the bounded natural kernel. Then implement
exact binary64 formatting with required notices and actual runtime selection.
Finally integrate bit-preserving float carriers, exact per-operation rounding,
Core/frame/source admission, result reporting and differential source matrices.
No helper prerequisite alone admits float source or completes numeric coverage.
Independent implementation/architecture/wiki review and supported-platform
validation remain promotion requirements; do not execute subagents.

## Resolved Grill Log

- **Q:** Use printf %g and compare a few examples? **A:** No; exact GHC show bytes are observable and require the locked digit/layout policy.
- **Q:** Compute Float32 directly with host float operations? **A:** Preserve the evaluator's Double operation followed by binary32 normalization unless equivalence is proven.
- **Q:** Use a fixed-size carrier for Pudu BigInt? **A:** No; the bounded natural is private formatter scratch with a finite IEEE-domain proof.
- **Q:** Enable source admission before formatting and rounding evidence? **A:** No; staged helper evidence is not public-language coverage.

## Dependencies and consumers

[[Float Literal]] · [[Eval Operator]] · [[Eval Render]] · [[Native Emission Coverage]] · [[Native Floating Natural Kernel]]

## Referenced by

[[architecture/_MOC]] · [[Native Floating Natural Delivery]]

## Arithmetic target contract (#510)

[[Native Floating Values]] preserves explicit uint64_t encodings through memcpy
and performs one volatile Double operation before optional volatile Float32
normalization. Exact raw-result/predicate comparison is required, including
NaN payloads and a noncontracted multiply/add chain. Explicit representation
assertions and rejection of unsafe optimization do not substitute for target
conformance. Foreign environment mutation remains a later adapter obligation.

Compiler references: [GCC floating implementation](https://gcc.gnu.org/onlinedocs/gcc/Floating-point-implementation.html)
and [Clang floating controls](https://clang.llvm.org/docs/UsersManual.html#controlling-floating-point-behavior).
These document target/optimization variation; no optional macro is treated as
proof of the required observable behavior. Helper tests do not admit source.

Resolved Grill Log: retain the evaluator's width/rounding policy and actual
predicates; require target evidence before broadening admission. Do not reset
floating state or silently rewrite NaNs to make a corpus pass.
