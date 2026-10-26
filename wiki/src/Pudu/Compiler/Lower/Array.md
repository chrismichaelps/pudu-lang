---
type: module
path: "@root/src/Pudu/Compiler/Lower/Array.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Array]
---
# Compiler Lower Array

## Purpose and interface

Arrays under [[Native Arrays]]: `lowerArrayLiteral`, `lowerArrayIndex`,
`lowerArrayMethod` and `takeReceiver`.

## Methods

The arguments run before the receiver, as every method call's do. `length`,
`isEmpty`, `get`, `indexOf`, `contains`, `push`, `pop`, `insert`, `remove`,
`slice`, `concat`, `reverse` and `join` (on text, or on a literal `[]`) are
runtime calls. `map`, `filter` and `reduce` become loops: the closure and the
array run once into hidden locals, the length is read once, and the closure is
called per item in order, with `reduce` passing the accumulator first, as
`foldM` does. A method the native subset lacks (`sortBy` for now) refuses by
name.

## Element types

The checked type at the literal or receiver decides the element type. An open
variable is admitted only at a literal `[]`, which holds no item, so a unit
layout serves. Anywhere else it may stand for a type real values have (#557),
and it stays unrepresented.

## Taking the receiver

`x = x.push(...)`, and likewise `pop`, `insert`, `remove` and `concat`, read
`x` last and replace it. `takeReceiver` turns that read into `CoreTakeLocal`,
so the buffer is not shared and the runtime may grow it in place.

## Resolved Grill Log

- **Q:** Why loops rather than a runtime `map`? **A:** A runtime helper would
  have to call back into the frame engine from C. As a loop, the closure call
  is an ordinary call through a value with depth checks and diagnostics.
- **Q:** Is taking safe when an argument reads the same variable? **A:** Yes.
  Arguments run first, so the take is the last read, and the runtime still
  checks the box has one owner before changing anything.
- Index failures report at the index (`readIndex`), `get` failures at the call.

## Dependencies and consumers

[[Compiler Lower State]] · [[Compiler Lower Types]] · [[Compiler Lower Control]] · [[Core IR]]

## Referenced by

[[Compiler Lower Body]] · [[Compiler Lower For]] · [[Native Arrays]]
