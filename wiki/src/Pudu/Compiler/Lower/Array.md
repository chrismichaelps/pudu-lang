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
`slice`, `concat` and `reverse` are runtime calls. `join` also calls the
runtime after any required dynamic member extraction. `map`, `filter` and `reduce` become loops: the closure and the
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

Resolved Grill Log (#887): a byte literal is an independent operand, like the
other literals, when an array method may take its receiver.

## Join on checked arrays (#956)

Lower direct and bound calls through `ArrayJoinWith` with the receiver's
exact element type. If a dynamic element can hold text, walk the retained
receiver in order and extract each checked text variant into a text array.
A different variant takes the ordinary invalid-member diagnostic. Dynamic
traits without a text variant use the non-text path.

### Resolved Grill Log

even when the element type differs from Str, the receiver
and separator finish before the runtime distinguishes an empty array from
one with an invalid member.

## Dynamic arguments to runtime methods (#956)

Resolved Grill Log: widen each supplied operand to its checked method
parameter before selecting the runtime call. This shares the array literal
conversion while preserving source arity and receiver-first evaluation.

## Runtime element carriers (#956)

Resolved Grill Log: checked types decide which operations are available.
Array construction and mutation encode every member in the chosen native
element layout. An update or concatenation that needs a broader layout
copies the retained source entries into the new layout. A read or
same-layout transformation uses the layout from the lowered receiver.
The receiver and arguments each run once in source order.

## Native callback signatures (#956)

Resolved Grill Log: array traversal uses the callback's exact frame
signature and preserves its result carrier when mapping. A reducer
uses a consistent accumulator layout for initialization, callback
input and subsequent turns. Receiver, callback and initial value
keep their source evaluation order.

## Joining selected text carriers (#956)

Resolved Grill Log: a boxed element contributes text only when its
held value is text. Evaluate the receiver and separator before walking
the array. An empty array joins without selecting a payload.

## Stored runtime callbacks (#956)

Resolved Grill Log: traversal uses the same call shape for each
selected callback body. Mapping keeps every reachable result layout;
reduction projects callback results into its accumulator.

## Runtime keyed layouts (#956)

Resolved Grill Log: Keyed collections reuse the array reboxing loop for keys and entry pairs.

## Mutable slot layout discovery (#956)

Resolved Grill Log: Array layout projection shares the widening operation used by mutable slots and keyed collections.

## Selected receiver layouts (#956)

Resolved Grill Log: Index the held array or text using its actual layout. Evaluate the index before reporting an unsupported receiver.

## Selected invocation arguments (#956)

Resolved Grill Log: Stop collecting at an argument that transfers control. Consumers preserve the evaluated prefix.

## Selected numeric keys

Scalar indexing retains the receiver before the key. Select both
held layouts only after their effects. Wider integers use the
existing bounds checks for arrays and text. If a check admits an
alternate tuple receiver, the position selects its actual payload.

Resolved Grill Log: a noninteger key produces the same receiver-kind
failure as the evaluator. A wider out-of-range integer remains an
index bounds failure, reported at the key.

## Exact range callback inputs

A range can materialize outside the ordinary Int layout. The shared
loop converts that array after the supplied callback and seed have
run. Its callback signature receives the retained element layout.

Resolved Grill Log: ordinary array loops reuse identity conversion.
The wide range arm specializes callbacks for exact Int elements.

## Dynamic array elements

Resolved Grill Log: project each element into the declared dynamic
layout, including reads of runtime alternatives.

## Held collection member selection

Resolved Grill Log: Array calls consume a retained receiver supplied by member selection. Callback specialization and copy-on-write continue to use its actual element layout.

## Held array method arguments

Resolved Grill Log: validate held array method slots after all operand
effects. Preserve unconstrained elements through structural widening.
Array method positions wrap before indexing, including values beyond
Int. An incompatible concatenation or separator keeps its specific
runtime diagnostic.

## Traversal callback failures

Resolved Grill Log: [[Compiler Lower Array Loop]] owns invocation
and predicate validation. The collection call retains its receiver
and callback before traversal.
