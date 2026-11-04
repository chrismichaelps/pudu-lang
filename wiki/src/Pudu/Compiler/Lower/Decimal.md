---
type: module
path: "@root/src/Pudu/Compiler/Lower/Decimal.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Decimal]
---
# Compiler Lower Decimal

Export decimalLiteral, lowerDecimalPrimitive and lowerTextToDecimal. A
literal becomes `CoreDecimalLiteral` of its coefficient and scale, or nought
for text no literal could spell, as the evaluator reads it. The seven
primitives behind `Std.Decimal` hold their arguments in order and answer
through `CoreDecimalMethod`; those answering an Option are a test and the
conversion it allows (`decimalOf`, `decimalToInt`), or None for a zero
divisor (`decimalDivide`), built at the Option the checker gave the call.

## Resolved Grill Log

Holding the arguments keeps each evaluated once, as `callDecimal` receives
them. See [[Native Decimal]].

## Callable bodies (#806)

Export decimalCallable, returning the primitive's exact Core function type
and a builder over held Core arguments. Direct calls and callable bodies
share answered; its Option layout comes from an explicit result type.
Direct calls supply the checked call fact; values supply the validated
callable result. No expression fact is overwritten or inferred.

Resolved Grill Log: the seven monomorphic signatures come from the same
primitive table as direct calls. Optional results require their exact Option
payload, and unrecognized names return Nothing. Argument retention and
conversion execute through the existing block/declaration path.

## Referenced by

[[Compiler Lower Body]] · [[Compiler Lower Text]] · [[src/Pudu/Compiler/_MOC]]
