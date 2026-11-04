---
type: architecture
aliases: [Native Wide Operations]
tags: [native, numeric, architecture]
---
# Native Wide Operations

## Contract

Implement the typed arithmetic/bitwise/shift adapter required by
[[Native Wide Integers]] using [[Backend Wide Integer Values]] and
[[Backend Word128 Kernel]]. Checked helpers call the existing supplied site
on mathematical overflow; divide/remainder zero use their supplied zero site.
These operations introduce no new language syntax, diagnostic code or type
admission, and do not change interpreter/checker behavior.

Same-sign magnitude addition retains carry; opposite signs subtract smaller
magnitude from larger and retain the latter's sign. Product retains upper-word
overflow and XOR sign. Subtraction flips bits/sign on the right before adding.
Do not normalize overflowing zero magnitudes before saturation uses their sign.
Checked results reject magnitude carry or limits violations; saturation selects
the actual-sign limit; wrapping decodes the low 128 bits. Signed positive
2^127 deferred operands stay positive until the result policy settles them.

Divide truncates toward zero and checks quotient bounds, including minimum/-1;
remainder keeps dividend sign and normalizes zero without quotient overflow.
Nonzero unsigned negation underflows. Checked signed minimum negation overflows.
Zero with a transient sign is normalized when emitted as an ordinary result.

Bitwise and/or/xor/not use two raw words and decode according to kind. Shift
counts use existing platform pudu_int, validate actual negative before >=128,
and only then convert to unsigned. Use raw shifts, with explicit high one-fill
for signed negative right shifts. Count zero still decodes according to kind;
positive deferred 2^127 is not sign-filled. Every helper has an explicit minimal
dependency closure, including existing site/fail/64-bit count types where used.

## Evidence and ownership

Backend Engineer owns Wide.Operations and library registration; Test Engineer
owns WideOperationsSpec and suite registration. Independent Integer tables
exercise signed/unsigned endpoints, deferred positive boundary, full-width
samples, checked overflow, zero divisors, wrapping/saturation, high-bit shifts
and exact refusal-site identity. Compile real C under Clang/GCC and sanitizers,
plus minimal selected helpers and full repository gates. Controlled nonreturning
failure stubs check primitive site routing; actual diagnostic text/spans, ordered
source effects and frame/public admission remain the subsequent integration
obligation. Independent review remains required before promotion.

## Resolved Grill Log

- **Q:** Normalize a carried negative zero before clamping? **A:** No; keep the negative overflow direction.
- **Q:** Reuse quotient overflow for remainder? **A:** No; minimum%-1 is zero.
- **Q:** Wrap checked negation? **A:** No; range failure reaches its supplied site.
- **Q:** Shift before checking counts? **A:** No; both count failures precede all C shifts.
- **Q:** Treat a deferred positive high bit as a negative sign? **A:** No; fill follows actual sign, then decode result.

## Dependencies and consumers

[[Native Wide Integers]] · [[Backend Wide Integer Values]] · [[Backend Wide Operations]] · [[Native Wide Operation Tests]]

## Referenced by

[[architecture/_MOC]] · [[Native Wide Integer Delivery]]
