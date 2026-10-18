---
type: module
path: "@root/src/Pudu/Backend/Runtime/Integer.hs"
fidelity: Active
aliases: [Backend Runtime Integer]
grammar: "[[grammar/haskell]]"
---
# Backend Runtime Integer

## Purpose and interface

Export integerRuntimeParts :: [(Text, [Text])], an ordered pure catalogue of
portable platform-Int C11 helpers consumed by [[Backend Runtime]]. No IO,
frontend or evaluator imports, new dependencies or target extensions.

## Algorithm and invariants

The existing target is 64-bit. from_bits converts uint64_t to int64_t without
out-of-range narrowing: if bits <= INT64_MAX cast directly; otherwise return
-1 - (int64_t)(~bits), whose complemented magnitude fits INT64_MAX.
Bitwise and/or/xor/complement and wrapping add/subtract/multiply use uint64_t
operations then this conversion. Unsigned overflow is the specified modulus.
Right shift validates count before shifting, returns a for zero, shifts unsigned
bits, then adds a high-bit sign mask for negative a. Left shift uses unsigned
bits and wraps. Both check negative then >=64 and call pudu_fail at distinct
sites from [[Diagnostic Arithmetic]]. No signed right shift or shift by 64.

Saturating add/subtract check safe bound differences before the operation and
return the appropriate signed limit on overflow. Saturating multiply returns
zero for zero, handles either MIN * -1 before division, checks each sign pair
by safe limit division, then multiplies only when the result fits. No signed
overflow, MIN/-1 division or compiler-specific builtins.

Parts: from_bits, bit_and/or/xor/not, shift_left/right, wrap_add/sub/mul,
sat_add/sub/mul. from_bits precedes its consumers; saturation does not require
it. Only shift helpers require site/fail. [[Backend Emit Support]] supplies
transitive selection so no unused helper is emitted.

## Resolved Grill Log

- **Q:** Cast high unsigned words directly to signed? **A:** No; that is implementation-defined in C11. Use the complemented in-range magnitude.
- **Q:** Use signed shifts for signed Pudu values? **A:** No; explicit sign filling preserves the interpreter independently of C implementation choices.
- **Q:** Compute then detect signed overflow? **A:** No; every signed arithmetic operation is preceded by a safe range proof.
- **Q:** Generalize this to other widths? **A:** Not in this module's admission contract; those remain explicit native coverage obligations.

## Dependencies and consumers

[[Backend Runtime]] · [[Backend Emit Support]] · [[Diagnostic Arithmetic]]

## Referenced by

[[src/_MOC]] · [[Native Emission Coverage]] · [[Native C11 Backend Delivery]]
