---
type: module
path: "@root/src/Pudu/Compiler/Lower/Default.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Default]
---
# Compiler Lower Default

Export takesSuppliedCount, suppliedArguments and lowerDefaultedBody. A function
with defaults has one extra trailing Int parameter, the count of arguments
the call supplied. lowerDefaultedBody lowers each default in the callee,
after the parameters before it are in scope, and puts
`if supplied <= i { parameter = default }` in front of the body for each
defaulted parameter i, in order. suppliedArguments builds a call's argument
list: what it wrote, a CoreAbsent zero per omitted parameter, then the count.

Only the trailing run of defaulted parameters can be omitted. Defaults
ahead of a required parameter occupy supplied positions. The hidden count
follows the written slots and does not appear in C export parameters.
The checked signature determines whether the count exists.

## Resolved Grill Log

The expression and body lowerers come in as arguments so Call can use the
helpers without importing Body. A default widens to its parameter type through the ordinary dynamic
conversion. A remaining type mismatch refuses with E6001; a Never default stops the prologue like any block. See
[[Native Default Parameters]].

## Referenced by

[[Compiler Lower]] · [[Compiler Lower Call]] · [[Compiler Lower Lambda]] · [[src/Pudu/Compiler/_MOC]]
