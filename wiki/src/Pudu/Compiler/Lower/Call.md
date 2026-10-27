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

## Output Results (#566)

Resolved Grill Log: lowerPrint takes the builtin name, lowers its one Str argument once and binds a CoreOutputError outcome. Empty error text constructs Ok(()); nonempty text constructs Err(text), using the exact solved Result[(), Str] fact. All four output builtin names share this path. See [[Native Output Results]].
