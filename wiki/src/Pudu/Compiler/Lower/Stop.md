---
type: module
path: "@root/src/Pudu/Compiler/Lower/Stop.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Stop]
---
# Compiler Lower Stop

Export lowerPanic and lowerUntypedConvert for direct calls, and panicBody and
untypedConvertBody for the value bodies [[Compiler Lower Intrinsic]]
registers. Direct calls run every argument first; an argument that stops
stops the call. Then CoreFailText ends the program at the call: E7007 with
the argument as message for panic, E7012 with the fixed message and help for
convertInteger. Value bodies use CoreFailCaller with the same codes.

## Resolved Grill Log

The message and help text are the interpreter's, copied once here. Direct
and value forms share these definitions. The result is Never; no Option is
constructed for an untyped conversion. See [[Native Stopping Builtins]].

## Referenced by

[[Compiler Lower Body]] · [[Compiler Lower Intrinsic]] · [[src/Pudu/Compiler/_MOC]]

## Arguments that are not one Str (#633)

Checking does not type panic (#634), so `panic(5)` and `panic()` reach
lowering. They run their arguments, then refuse E7007 "panic" with help
"panic takes one string argument", directly or through a value
(wrongPanicBody), as the interpreter does.
