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

The receiver runs before the supplied arguments. `length`,
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

`x = x.push(...)`, and likewise `pop`, `insert`, `remove` and `concat`, replace
`x`. `takeReceiver` takes it only when the argument expressions can neither
observe the cleared binding nor transfer before the assignment completes.

## Resolved Grill Log

- **Q:** Why loops rather than a runtime `map`? **A:** A runtime helper would
  have to call back into the frame engine from C. As a loop, the closure call
  is an ordinary call through a value with depth checks and diagnostics.
- **Q:** Can taking clear a binding that an argument observes? **A:** No.
  Only scalar literals and reads of a different local qualify. Every other
  argument keeps the shared receiver snapshot.
- Index failures report at the index (`readIndex`), `get` failures at the call.

## Dependencies and consumers

[[Compiler Lower State]] · [[Compiler Lower Types]] · [[Compiler Lower Control]] · [[Core IR]]

## sortBy and Str indexing (#558)

Resolved Grill Log: `sortBy` evaluates the array and then the closure into
hidden locals and hands them to [[Compiler Lower Sort]]. `text[i]` is
`charAt`, which fails exactly as `readIndex` does. Hold the text before the index runs.
`collect`, `stops` and `stopped` are exported for [[Compiler Lower Slice]].

## Loops over converted receivers (#564)

Resolved Grill Log: `lowerArrayLoop` runs `map`, `filter` and `reduce` over a
receiver retained before the arguments. Conversion to items runs after
all operands, which is how a range's values feed the same loops.
`receiverOperands` and `arrayMethodWith` hold what the two share.

## Referenced by

[[Compiler Lower Body]] · [[Compiler Lower For]] · [[Native Arrays]]

takeReceiver also takes the local for ArrayReplaceAt. (#649)

## Dynamic items (#846)

An array literal whose expected element is `dynamic` widens each item of an
implementing type before the equality check, so a homogeneous dynamic array is
admitted. Resolved Grill Log: widening happens after every item ran and keeps
the literal's element type.
