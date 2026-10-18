---
type: architecture
aliases: [Native Wide Integers]
tags: [native, numeric, architecture]
---
# Native Wide Integers

## Contract and sequence

Preserve the ordinary interpreter's exact Int128/UInt128 behavior using portable
C11, without compiler-specific integer extensions. Stage the delivery as a raw
unsigned word kernel, exact signed carriers/policies, then frame and emitter
integration plus full source differential corpora. The kernel alone does not
admit a new Pudu type or increase completed numeric coverage.

The raw word is two uint64_t members named low/high, interpreted as
low + 2^64 * high regardless of byte order. Addition returns the low 128 bits
and a carry flag. Subtraction returns the difference modulo 2^128.
Multiplication returns the low 128 bits and whether the mathematical product
exceeds 2^128-1. Compare returns -1/0/1. Shifts accept unsigned counts, return
zero for counts >=128, and never shift a C operand by its storage width.
These raw total shifts are not the checked Pudu shift API.

Division returns quotient/remainder for nonzero divisors. For zero, return
zero quotient/remainder with an explicit zero-divisor flag; the future typed
adapter supplies the existing source diagnostic, without executing C division
by zero. Use bounded 128-step long division retaining the extra remainder bit
before subtracting a high-bit divisor. Multiplication uses four base-2^32
limbs, eight result limbs and uint64_t accumulators with a proven maximum of
2^64-1 for each inner sum. All arithmetic is unsigned; no heap allocation,
platform endian assumption, pointer aliasing or external library is needed.

The later exact signed carrier must keep actual sign separate from bit pattern
so deferred positive 2^127 does not become negative. Checked/saturating/wrapping
policies, signed division/remainder, diagnostics, decimal printing and status
clamping remain separate consumers. Mixed programs need a wide cell member;
programs using only existing kinds must retain their current frame layout.
Runtime revision changes only when the production ABI is integrated. Select
raw helpers and their dependency closure individually: embedding this complete
kernel when only one helper is called triggers Clang unused-function errors.
Do not suppress warnings or add compiler-specific unused attributes.

## Exact carrier and typed adapter obligations

Use a wide carrier with raw two-word bits and an actual-negative flag. Its
magnitude is either bits or 0-bits modulo 2^128. Normalize mathematical zero
before comparing against unsigned bounds, so a zero result with a transient
negative flag is accepted. Same-sign addition combines magnitudes and the raw
carry; opposite signs subtract smaller magnitude from larger. Subtraction
flips the second operand's sign and bits before that same computation. Product
sign is XOR and overflow comes from the full raw product. A magnitude overflow
is retained separately until checked, wrapping or saturation policy settles it.

Signed limits are positive 2^127-1 and negative magnitude 2^127; unsigned limits
are positive 2^128-1 and negative magnitude zero. Checked results reject a carry
or out-of-interval magnitude through the existing width-specific E7005 site.
Saturation clamps using actual sign; wrapping decodes the low 128 bits. Preserve
positive deferred 2^127 in transfers, comparisons and division. Division truncates
toward zero and remainder keeps the dividend sign, normalizing zero. Negating
the signed minimum overflows; unsigned nonzero negation underflows. Bitwise
operations decode the exact two-word result with the selected signedness.

Shift counts retain the existing platform-Int carrier and exact E7004 sites.
Validate negative and >=128 before conversion. Signed right shift fills from
the operand's actual sign, including accepted deferred values whose bit pattern
has the high bit set while actual sign is positive; unsigned right shift fills
with zero. Both then decode according to the result kind, matching the ordinary
arbitrary-precision implementation rather than implementation-defined C shifts.
Decimal printing repeatedly divides the magnitude by ten into a bounded local
buffer (39 digits plus sign); entry status uses all high bits before clamping.

Full source integration must cover aliases, inferred signatures, mixed narrow/
wide functions, locals, ordered argument snapshots, branches, Never joins,
loop transfers, recursive frames and cleanup. Slot member and print/status
selection must use canonical kinds. Minimal translations (literal-only,
print-only, unit entry with wide locals, comparison-only, isolated operations)
must remain strict warning-free C11 without unused runtime helpers.

## Evidence and ownership

Backend Engineer owns Runtime.Integer.Word128 and its manifest registration.
Test Engineer owns Word128Spec, test registration and runner integration.
Test emitted kernel C with independent Haskell Integer answers, endpoint and
carry/borrow/high-product values, quotient/remainder and all shift boundaries.
Strict C11 warning checks, ASan/UBSan, full gates and independent review precede
promotion. Keep future source-language admission pending until both evaluators
and emitted executables agree across full signed/unsigned corpora.

## Interpreter anchor

A local checked source probe confirms both tree and compiled evaluators retain
positive 2^127 through an Int128 call after a later negation constrains the
literal. Signed right shift by zero then wraps to the negative minimum; by 64
it yields positive 2^63. The negative minimum shifted by 64 yields -2^63;
its remainder by -1 is zero, wrapping subtraction by one yields the maximum,
and saturating subtraction stays at the minimum. UInt128 maximum shifted by
127 yields one. These are required source integration regressions, not native
admission evidence. Local artifacts: ~/.codex/tmp/pudu-wide/WideOracle.pudu
and wide-oracle.json.

## Resolved Grill Log

- **Q:** Depend on __int128? **A:** No; two uint64_t words make the baseline portable.
- **Q:** Reuse a C signed high word? **A:** No; overflow and right shifts must be explicitly defined.
- **Q:** Ignore carry out of a division remainder? **A:** No; preserve that bit before each reduction.
- **Q:** Is a low-word product enough for checked multiplication? **A:** No; retain upper limbs to prove overflow.
- **Q:** Treat kernel tests as language completion? **A:** No; typed policies and emitter integration remain required.

## Dependencies and consumers

[[Native Unsigned Integers]] · [[Exact Native Integer Carriers]] · [[Native Execution Frames]] · [[Backend Word128 Kernel]] · [[Native Word128 Tests]]

## Referenced by

[[architecture/_MOC]] · [[Native Wide Integer Delivery]] · [[Native Emission Coverage]]

## Selectable values (#502)

Keep word128Runtime as the complete ordered compatibility view; also export
word128RuntimeParts and word128RuntimeDependencies for minimal helper closure.
Each raw helper depends on word128_value; division additionally needs zero,
left, compare and sub. No arithmetic body changes in this partition.

Wide.Value exports wideValueRuntimeParts and wideValueRuntimeDependencies.
wide_value defines pudu_wide_int {pudu_word128 bits; int negative;},
pudu_wide_kind {int is_signed;} and pudu_wide_calculation {value; int overflow;}.
wide_make preserves a requested negative flag even on zero: an overflowing
negative calculation may wrap its magnitude to zero but must still saturate
toward the negative bound. wide_normal explicitly canonicalizes zero at value
boundaries. wide_magnitude recovers unsigned magnitude via modular negation.
wide_from_bits decodes according to kind, wide_compare normalizes zeros and
compares actual signs before unsigned words, and wide_limit returns the exact
positive/negative magnitude limit. No source admission, existing frame change,
new error code or public syntax is part of this prerequisite.

Backend Engineer owns Word128 catalogue extraction and Wide.Value plus the
production manifest. Test Engineer owns WideValueSpec and suite registration.
Execute exact make/magnitude/normal/from-bits/compare/limit cases and every
single-helper dependency closure under strict C11. Include requested negative
zero, signed/unsigned high bits and positive deferred 2^127. Retain the original
raw arithmetic corpus unchanged, then run sanitizers, GCC and full gates.
Resolved Grill Log: normalize only when the mathematical sign is no longer
needed for an overflowing calculation; no unused-warning suppression, sign-bit
shortcut, silent dependency omission or typed admission is permitted.
