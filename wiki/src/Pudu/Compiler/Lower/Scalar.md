---
type: module
path: "@root/src/Pudu/Compiler/Lower/Scalar.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, backend, compiler]
aliases: [Compiler Lower Scalar]
---
# Compiler Lower Scalar

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
on Bool/Unit uses cannot-apply-unary. Valid unimplemented Int operations and
unrepresented owned types still refuse E6001.

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
