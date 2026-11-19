---
type: module
path: "@root/src/Pudu/Eval/Call/Argument.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, runtime]
aliases: [Eval Call Argument]
---

# Eval Call Argument

## Purpose and interface

Evaluate call arguments and receivers while recording the places they lend.

## Algorithm and invariants

`argumentOf` evaluates an ordinary argument left to right and records a bare
name's place; `&mut` resolves and reads its place once with `AtRoot`, so a loan
fails at the root name, as a store into the same place does. `argumentPlace`
recognizes bare names. `receiverOf` resolves index-selected receivers through
their places and reads them with `AtKey`, so an out-of-range element fails at its
key as reading the same element as a value does; a range receiver fails at the range
that chose it. Other receivers are evaluated once. `chosenByElement` follows member and
dereference wrappers to detect an index. Failure to resolve a place retains the
ordinary evaluator fallback.

## Dependencies and consumers

Requires [[Eval Env]], [[Eval Value]], [[Syntax Tree]] and [[Syntax Located]].
Argument additionally consumes [[Eval Call Needs]] and [[Eval Place]].
Consumed by [[Eval Call]]; Argument is also a consumer of Needs.

## Negative logic

No evaluator import cycle, new dispatch semantics or changes to evaluation order.
The extraction preserves the existing call/lending contract.

## Grill Log

Resolved: separate argument/receiver place discovery from function dispatch, and
place the callback record below both modules so Call remains below 500 lines.
No new capability, reference representation, arity rule or effect policy is added.

- **Q:** Why does a loan blame the root while a receiver blames the key? **A:** A loan names a place
  to write back into, and every write to a place reports at its root; a receiver only reads the
  element, so it reports where an element read does.

- **Q:** Does a range receiver blame the value it slices? **A:** A range chooses the stretch as a key chooses an element; both report where they were written.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[src/_MOC]] · [[Eval Call]]
