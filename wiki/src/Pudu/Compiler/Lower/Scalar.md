---
type: module
path: "@root/src/Pudu/Compiler/Lower/Scalar.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, backend, compiler]
aliases: [Compiler Lower Scalar]
---
# Compiler Lower Scalar

## Fixed signed admission (#497)

Fold pure immediate negation for every admitted kind when the mathematical
result fits; other negate/complement operations retain that operand kind.
Represent same-kind integer arithmetic/comparisons. Handle shifts before the
same-kind guard: left is admitted integer, count is platform Int, result is
left kind. Existing supported Bool/unit failures retain settled-fact checks;
two integer operands outside represented operators remain E6001, not a fake
E7001 for a range. Resolved Grill Log: preserve exact type identity, operand
order, spans and runtime-bound settlement rather than narrowing values early.

## Purpose and interface

Own unary/binary scalar representation and operator failure admission outside
[[Compiler Lower Body]]. Export lowerUnary, lowerBinary and eagerType. Each
lowering function accepts the body's expression callback and state, then the
operator span, syntax operator and located operands. There is no recursive
module dependency or second inference pass.

## Algorithm

Lower operands in source order through the callback. Logical operands remain
Bool/Never and the right stays guarded in CoreBinary. Eager Never operands
become an ordered Core block without an operator or fabricated failure.
Normal operands cannot carry effect-only print Result values. Existing Int
arithmetic/comparisons and scalar equality remain; Bool ordering is also valid
and uses its actual false-before-true order.

Unsupported normal operations on represented Unit/Bool operands become
CoreOperatorFailure with the original whole-operation span, ordered operands
and shared interpreter message. Require exact settled scalar facts on trap
operands, including Int shift counts. Bool/Bool invalid operations use the
comparison-only unsupported-operator text; unit and mixed shift operands use
cannot-apply with canonical runtime kind labels. Unary invalid minus/complement
on Bool/Unit uses cannot-apply-unary. Unrepresented numeric families and owned types still refuse E6001; platform
Int operators are admitted by #495. Deferred out-of-range intermediates remain
a separate representation gap tracked in #498.

## Dependencies and consumers

[[Compiler Lower State]] · [[Compiler Lower Types]] · [[Compiler Lower Control]] ·
[[Diagnostic Evaluation]] · [[Pudu Core]] · [[Frontend Syntax]].
Consumed by [[Compiler Lower Body]]; registered in [[Pudu Cabal Manifest]].

## Resolved Grill Log

- **Q:** Treat Bool ordering as failure? **A:** No; the interpreter orders Bool values. Inspect its dispatch before classifying failure.
- **Q:** Share one failure text for Bool and Unit? **A:** No; retain comparisonOnly versus generic-combine messages through shared factories.
- **Q:** May print's effect-only Unit select a trap? **A:** No; carrier guards and exact scalar facts reject Result erasure. A Never operand may discard completed effects because no operator can consume its values.
- **Q:** Can a trap precede the second operand? **A:** No; both operands finish first unless an operand transfers or fails. Logical right operands remain guarded.

## Referenced by

[[Compiler Lower Body]] · [[Pudu Cabal Manifest]] · [[Native Emission Coverage]]

## Platform Int operators (#495)

Map every represented platform Int bitwise, shift, wrapping and saturating spelling to its dedicated Core form. Complement maps to CoreComplement. Preserve Never sequencing, Result carrier guards, Bool/Unit E7001 and unrepresented numeric E6001. Do not mark full numeric families complete.

Resolved Grill Log: use defined unsigned bit patterns, validate counts before shifts, and prove signed arithmetic bounds before evaluation. The actual interpreter determines results, effect order and exact diagnostic vocabulary. No syntax or type-inference change.

### Signed minimum literal admission

A checked immediate negation of a supported ResolvedInteger is a literal when
its mathematical negation fits that kind. Emit it at the whole unary span.
The exact carrier also preserves accepted positive-boundary intermediates in
blocks/locals/calls. Nonliteral negations and values whose negation does not
fit retain the checked helper with their declared kind's bounds.

Resolved Grill Log: fold only pure immediate canonical integer literals whose
negated result fits the existing kind bounds. Preserve runtime overflow for
negating the minimum value read from a local/function or outer negation.
