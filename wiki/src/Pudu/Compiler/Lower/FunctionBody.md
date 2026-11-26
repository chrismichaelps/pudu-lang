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

## Resolved Grill Log for #876 — Native callback lowering

A callback token can return from an ordinary lowered function as its nominal
native scalar.

## Referenced by

[[Compiler Lower Body]] · [[src/Pudu/Compiler/_MOC]] · [[Pudu Cabal Manifest]]

## Runtime carriers at the body boundary (#956)

Resolved Grill Log: project a tail into the current signature and
publish any further carrier discovered for an internal body. A
different carrier is admitted only while the worklist settles the
compatible caller and callee layout.

## Native task result layouts (#956)

Resolved Grill Log: Return the settled task closure from internal async functions. Keep the declared signature at fixed boundaries.

Resolved Grill Log: async entry reporting reads the selected Result
layout, including when the failure payload uses an alternate native
carrier. It keeps the entry's status convention.

## Dynamic defaults

Resolved Grill Log: project a selected default into the checked
dynamic parameter layout before the entry binds it.

## Owned parameters and the closed body (#1028)

A function's parameters are adopted before its body is lowered, so a
parameter that owns a value needing drop is dropped when the function's scope
ends. The body is then closed through `closingScope`, which keeps the body's
result, drops what the scope owns, and leaves a body that never returned
alone.

Resolved Grill Log: parameters are ordinary owned binders of the callee; the
caller's move facts decide whether the callee holds the only reference.

## Async parameter ownership (#1028)

A named async function passes the ownership set of its parameters, from
`ownedLocals`, to `lowerTask`, so its task drops them when the body ends. The
async entry passes the empty set: its parameters are defaults bound before the
task and are captured into it. The named-function path reads its parameter locals through one `parameterLocals` binding, shared by the async and ordinary branches.
