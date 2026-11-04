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

## Referenced by

[[Compiler Lower Body]] · [[Compiler Lower Text]] · [[src/Pudu/Compiler/_MOC]]
