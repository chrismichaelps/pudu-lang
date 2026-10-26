---
type: module
path: "@root/src/Pudu/Compiler/Lower/Call.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Call]
---
# Compiler Lower Call

Direct calls and the rendering builtins, moved out of [[Compiler Lower Body]]
to keep that traversal under its size limit (#556).

`lowerFunctionCall` admits the callee through [[Compiler Lower Generic]],
lowers the arguments in order and queues the target. `lowerPrint` keeps
print's Result effect-only. `lowerRendered` lowers `display` and `show` of any
represented value.

## Resolved Grill Log

- A move, not a change: the code and its refusals are what Body had.

## Referenced by

[[Compiler Lower Body]]
