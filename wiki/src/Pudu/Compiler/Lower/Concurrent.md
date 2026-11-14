---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Compiler/Lower/Concurrent.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Concurrent]
---
# Compiler Lower Concurrent

Export lowerConcurrentPrimitive, concurrentCallable and concurrentPrimitive.
The host builtins whose signature holds a type parameter live here:
`cellOpen`, `cellGet`, `cellSwap`, `channelPush`, `channelPull`,
`channelPullWithin` and `spawnThread`, as direct calls and as callable bodies
over a solved signature.

A held value crosses to the runtime as a box of one member, so the runtime
stores every type the same way and the function that releases the box names
its type. An answer that may be absent or failed is read from the host state
after the call: done, failed with the host's message, nothing there, or ended.

## Resolved Grill Log

Operands run once in source order and stop on Never before later ones. A
direct call and a callable body share one builder per builtin. Only an exact
checked signature is admitted; anything else refuses where it is written.

## Referenced by

[[Compiler Lower Primitive]] · [[Compiler Lower Intrinsic]] · [[Native Host Services]]
