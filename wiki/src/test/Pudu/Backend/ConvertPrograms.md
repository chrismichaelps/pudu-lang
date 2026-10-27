---
type: module
path: "@root/test/Pudu/Backend/ConvertPrograms.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Convert Programs]
---
# Backend Convert Programs

Exports convertSuccessPrograms and convertRefusalPrograms.

Resolved Grill Log: `convertInteger` at, inside and one past the bounds of
UInt8, Int8, Int16, UInt16, Int32 and UInt32; UInt64 above Int's range and
negative values into unsigned kinds; Int128 and UInt128 as both source and
target, at their extremes; conversions inside `match`, `if let` and a
function using `?`; and generic functions called with written type
arguments. The refusal overflows a converted UInt8.

## Referenced by

[[Backend Module Programs]] · [[Backend Text Leak Tests]] · [[Compiler Lower Convert]]
