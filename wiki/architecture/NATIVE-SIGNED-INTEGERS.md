---
type: architecture
aliases: [Native Signed Integers]
tags: [native, numeric, architecture]
---
# Native Signed Integers

Local admission is implemented and validated: all 19 clean gates/669 groups
pass, with independent signed matrices, strict C11 and production sanitizer
execution against both evaluator paths. [[Native Signed Integer Delivery]]
records exact evidence and pending reviews/platforms. No broader numeric or
100% completion claim follows this result.

## Scope and identity (#497)

Admit canonical Int8, Int16, Int32 and Int64 beside platform Int. Only the
compiler-wired NominalId Nothing identity with no type arguments may project
through integerKindOf; user-owned nominal names never choose representation.
Aliases and inferred signatures consume settled facts. Int64 and platform Int
remain distinct Core IntegerKind constructors even on a 64-bit target.
Unsigned, Int128, BigInt, floats and Decimal remain subsequent obligations.

## Representation and operations

Use the revision-5 exact carrier and existing frame cells. No narrowing occurs
on literals, locals, arguments, branch/loop slots or returns: the evaluator can
retain a deferred positive magnitude at the negative endpoint's absolute value.
Admit a resolved literal when it or its negation fits its canonical supported
kind. Immediate pure negation folds only when the result fits. Other negation
uses the checked helper with the declared bounds and original operation span.

Checked add/subtract/multiply/divide settle against the operation kind. Wrapping
and bitwise operations decode at that width; saturation clamps to its endpoints.
Remainder keeps its existing dividend-sign mathematical behavior. The existing
unsigned arithmetic kernels must not be replaced by narrower signed C operations.
Integer comparisons use exact mathematical ordering, including deferred values.

Same-kind arithmetic/comparisons retain the canonical kind. Shifts are the
explicit asymmetric case: left is any admitted integer kind, count is platform
Int, result is the left kind. Check -1 and width at runtime with the left kind's
E7004 vocabulary, after both operand effects. No implicit conversion or guessed
result kind. Existing Bool/unit operations, E7001 traps, Never sequencing and
print Result guards remain. Unsupported ranges/owned operators still refuse.

## Admission boundaries

Compiler Lower Types owns nativeIntegerKind and nativeScalarType predicates.
Signature, local, display and loop-break admission use those predicates; Never
stays explicit. Entry results may carry any admitted integer kind and use the
existing IntValue status clamp. Bool/owned entry reporting remains separate.
No new runtime ABI, allocation policy, parser or checker rule is introduced.

## Evidence and promotion

Require canonical and fake-identity projections, aliases/inferred signatures,
context-selected unsuffixed literals, suffix/base spellings, extrema, checked
success/failure, mathematical wrapping/saturation/bitwise/shift expectations,
whole-operation diagnostics, mutation/order, recursion, unit parameters, Never
transfers and deferred boundaries. Compare actual native programs with both
evaluators; use strict C11 and sanitizers. Complete repository gates and
independent implementation/architecture/wiki review precede promotion. The
numeric-family ledger stays Partial and the full 100% objective remains active.

## Resolved Grill Log

- **Q:** Use an int64_t carrier or assume source values always fit signed 64? **A:** No; reuse the exact carrier and preserve deferred magnitudes.
- **Q:** Treat Int64 as Int? **A:** No; identity and diagnostic names remain distinct.
- **Q:** Require a narrow shift count? **A:** No; the grammar/checker requires platform Int.
- **Q:** Normalize parameters to their declared width? **A:** No; that would change accepted deferred values before an operation settles them.
- **Q:** Mark all numeric families complete? **A:** No; this admits four signed families only.

## Dependencies and consumers

[[Exact Native Integer Carriers]] · [[Native Execution Frames]] · [[Compiler Lower Types]] ·
[[Compiler Lower Signature]] · [[Compiler Lower Scalar]] · [[Compiler Lower Body]] · [[Compiler Lower Control]]

## Referenced by

[[architecture/_MOC]] · [[Native Signed Integer Delivery]] · [[Native Emission Coverage]]
