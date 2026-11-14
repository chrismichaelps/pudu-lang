---
type: module
path: "@root/src/Pudu/Backend/Runtime/Float/Natural.hs"
fidelity: Active
aliases: [Native Floating Natural Kernel]
grammar: "[[grammar/haskell]]"
---
# Native Floating Natural Kernel

## Purpose and interface

Export floatNaturalRuntimeParts :: [(Text, [Text])] and
floatNaturalRuntimeDependencies :: Text -> [Text]. Embed portable unsigned C11
for private decimal-formatting scratch, with no allocation, evaluator/frontend
import or public numeric/source admission. [[Native Floating Point]] owns why
1280 bits suffice for the later locked binary64 formatter.

float_nat_value defines pudu_float_nat {size_t length; uint32_t words[40];}.
Words are little-endian limbs; length 0 means zero and otherwise the highest
used limb is nonzero. Unused limbs have no mathematical significance.
Named parts define pudu_float_nat_from_shift(out, uint64_t, uint32_t),
compare(a,b), add(out,a,b), sub(out,a,b), multiply_small(out,a,uint32_t),
scale10(out,a,uint32_t) and digit(out,unsigned *digit,a,b).
All mutating functions return int success and preserve outputs on failure.
compare returns -1/0/1. Output/input aliasing is supported.

## Algorithm and failure contracts

from_shift constructs word * 2^shift; zero succeeds for any shift and a nonzero
out-of-capacity value fails without undefined shifts. add and multiply_small
use uint64_t carry accumulators; overflow beyond 40 limbs fails atomically.
sub requires a >= b, propagates borrow and normalizes leading zeros; otherwise
it fails atomically. scale10 applies checked multiplication by ten, stops on the
first overflow and handles zero without work proportional to a huge exponent.
digit requires a nonzero divisor and quotient <=9, returns exact remainder and
digit, and otherwise preserves both outputs. Bounded repeated subtraction is
sufficient and rejects the tenth subtraction. It is not general division.

Dependencies are explicit and ordered; each root compiles with exactly its own
prerequisites. Keep below 500 lines. No extension integers, signed arithmetic
overflow, unchecked array indices, allocation, libc floating formatting or
unbounded work for out-of-domain exponents.

## Resolved Grill Log

- **Q:** Treat capacity exhaustion as a wrapped natural? **A:** No; return failure and leave the caller's outputs unchanged.
- **Q:** Break when an output aliases an input? **A:** Compute into bounded local scratch and publish only after success.
- **Q:** Loop UINT_MAX times to scale a nonzero number? **A:** Overflow occurs within the finite capacity; return immediately. Zero returns immediately too.
- **Q:** Claim BigInt or Float source support? **A:** No; this kernel is formatter scratch only.

## Dependencies and consumers

[[Native Floating Point]] · [[Native Floating Natural Tests]] · [[Backend Runtime]]

## Referenced by

[[src/_MOC]] · [[Backend Module Map]] · [[Native Floating Natural Delivery]]
