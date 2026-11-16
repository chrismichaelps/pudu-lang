---
type: module
path: "@root/src/Pudu/Compiler/Lower/FunctionBody.hs"
fidelity: Active
domain: "[[Core IR]]"
subsystem: "[[Backend]]"
grammar: "[[grammar/haskell]]"
tags: [module, backend, compiler]
aliases: [Compiler Lower Function Body]
---
# Compiler Lower Function Body

## Purpose and interface

Own the boundary between a checked function and the Core body
[[Compiler Lower Body]] traverses. `lowerEntryBodyWith` shapes a program entry;
`lowerFunctionBodyWith` shapes a named function against its admitted
signature. Both take the body module's expression and block callbacks, so the
mutual recursion between blocks and expressions stays in one place and this
module never imports it.

```haskell
lowerEntryBodyWith :: LowerExpression -> LowerBlock -> Located Function -> LowerState
  -> (LowerState, Maybe CoreFunction)
lowerFunctionBodyWith :: LowerExpression -> LowerBlock -> Located Function -> CoreSignature -> LowerState
  -> (LowerState, Maybe CoreFunction)
```

## Entry boundaries

The generated entry has no ABI parameters and passes shared function admission. A plain
entry reports the admitted carrier of its body: integer, Bool, float, Str,
Char, tuple, record, sum, function, array, tree, range, bytes, Decimal,
foreign handle, unit or Never's unit ABI. An async entry is awaited immediately: the body is
lifted as a task, then a Result success becomes the entry's answer while a
failure is printed and becomes the exit status.

## Foreign handle entry (#853)

Resolved Grill Log: preserve the handle carrier for entry reporting. Its
rendered address stays available after the runtime releases the claim.

## Named function boundaries

An async function answers the task of its body and runs nothing until an
await. Any other function lowers its block and widens the result to the
settled signature; a body returning the printed `Result[(), Str]` carrier is
refused.

Resolved Grill Log: keep one expression/block traversal and one dispatcher.
Entry and named-function shaping are a function-boundary responsibility, not
an expression one, so moving them here removes a second architectural concern
from Compiler Lower Body without introducing callbacks in the other
direction.

## Entry parameters (#871)

An argument-free entry binds defaults in declaration order using its checked
parameter carriers. Each default sees earlier bindings. The first missing
required parameter reports E7003 at the entry name after preceding effects.
A default that stops prevents later defaults and the body from running.
The async entry captures the bound values into its task.

Resolved Grill Log: keep the generated ABI parameterless and use ordinary
Core declarations for entry defaults. The body and async task retain their
existing reporting paths.

## Referenced by

[[Compiler Lower Body]] · [[src/Pudu/Compiler/_MOC]] · [[Pudu Cabal Manifest]]
