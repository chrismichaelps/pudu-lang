---
type: module
path: "@root/src/Pudu/Backend/Runtime/Float/Value.hs"
fidelity: Active
aliases: [Native Floating Values]
grammar: "[[grammar/haskell]]"
---
# Native Floating Values

## Purpose and interface

Export floatValueRuntimeParts :: [(Text,[Text])] and
floatValueRuntimeDependencies :: Text -> [Text]. Embed named strict C11 helpers
for raw binary64 values, with Float32 values stored as normalized widened bits.
No source admission, active runtime selection or revision change belongs here.

float_target asserts binary32/binary64 sizes, radix, mantissas, exponent ranges
and FLT_EVAL_METHOD zero. Reject fast-math and finite-only compilation with a
stable explanatory C error. Required headers are float.h, limits.h, stdint.h and
string.h. These are ABI prerequisites, not proof of IEEE semantics. The optional
IEC macro is not required: both tested Mac compilers omit it.

float_decode/pudu_float_decode(uint64_t) returns double by memcpy;
float_encode/pudu_float_encode(double) returns the exact encoding by memcpy.
No union punning, pointer aliasing, decimal conversion or canonical NaN rewrite.
float_normalize/pudu_float_normalize(double,int narrow) returns uint64_t;
when narrow is nonzero store through volatile float, widen to double and encode.
Otherwise encode the supplied Double directly. Each arithmetic helper
pudu_float_add/sub/mul/div(uint64_t a,uint64_t b,int narrow) decodes operands,
loads decoded left/right operands into separate volatile doubles in source
order, stores its single Double result in a volatile double, then normalizes.
NaN operands take a noncommutative subtraction path for target NaN propagation,
then the same width normalization. On the tested IEEE ABI all four operations
share that observed NaN propagation rule.
Addition/multiplication alone may be commuted by Clang/GCC even with volatile
operand stores, changing payloads in a nested call. The raw corpus must prove
this propagation path against GHC on each admitted target; do not infer it from
IEEE dimensions. Non-NaN exceptional operations still execute their actual
operator. Never
replace this with direct Float32 arithmetic or fuse successive Pudu operations.

float_neg/pudu_float_neg(uint64_t) flips only bit 63; operand width already
constrains the value, matching evaluator unary negation without normalization.
float_eq/ne/lt/le/gt/ge return int using their actual C floating predicate on
decoded operands. NaN ordering is unordered, not integer three-way comparison.
All roots have explicit minimal dependencies in catalogue order.

## Target and failure contract

This helper targets the same IEEE ABI as the locked GHC evaluator. C11 syntax
and dimensions alone cannot guarantee NaNs, subnormals or overflow semantics;
actual compiler/target differential evidence is required before source admission.
The ordinary toolchain's precise optimization policy stays unchanged. No helper
resets rounding mode, clears exception flags, changes denormal policy or performs
process IO. Floating exception-flag parity is not established by raw-bit tests. Foreign
floating-environment mutation and additional supported targets remain explicit
integration obligations, not claims inferred from the default-host corpus.

The current scope has no user runtime failure: division by zero produces the
same IEEE exceptional values as evaluation. Compiler policy/ABI violations fail
at C compilation; later source integration must retain typed toolchain errors.
No allocation, IO, BigInt, Decimal or interpreter fallback.

Controlled target probes also compare exception flags and all four standard
rounding modes against optimized GHC. A traced GC event can intervene in the
GHC flag window; larger-heap results match, but foreign-environment isolation
remains an integration obligation. This does not weaken raw-value/predicate
parity or authorize resetting the process floating environment.

## Resolved Grill Log

- **Q:** Does volatile alone prove arbitrary target equivalence? **A:** No; require the ABI checks and actual target conformance, and keep unsupported targets explicit.
- **Q:** Canonicalize NaNs because display hides payloads? **A:** No; bit transport and arithmetic tests retain raw encodings for later interop.
- **Q:** Negate through normalization? **A:** Flip the sign bit of the already represented operand, preserving payload and negative zero.
- **Q:** Treat zero division as integer E7004? **A:** No; IEEE results are ordinary floating values.

## Dependencies and consumers

[[Native Floating Point]] · [[Native Floating Value Tests]] · [[Pudu Cabal Manifest]]

## Referenced by

[[src/_MOC]] · [[Backend Module Map]] · [[Native Floating Value Delivery]]
