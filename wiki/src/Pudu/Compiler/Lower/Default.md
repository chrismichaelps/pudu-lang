---
type: module
path: "@root/src/Pudu/Compiler/Lower/Default.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Default]
---
# Compiler Lower Default

Export hasDefaults, suppliedArguments and lowerDefaultedBody. A function
with defaults has one extra trailing Int parameter, the count of arguments
the call supplied. lowerDefaultedBody lowers each default in the callee,
after the parameters before it are in scope, and puts
`if supplied <= i { parameter = default }` in front of the body for each
defaulted parameter i, in order. suppliedArguments builds a call's argument
list: what it wrote, a CoreAbsent zero per omitted parameter, then the count.

## Resolved Grill Log

The expression and body lowerers come in as arguments so Call can use the
helpers without importing Body. A default of another type refuses with
E6001; a Never default stops the prologue like any block. See
[[Native Default Parameters]].

## Referenced by

[[Compiler Lower]] · [[Compiler Lower Call]] · [[Compiler Lower Lambda]] · [[src/Pudu/Compiler/_MOC]]
