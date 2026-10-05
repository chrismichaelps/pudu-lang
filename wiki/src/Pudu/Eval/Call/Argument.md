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
name's place; `&mut` resolves and reads its place once. `argumentPlace` recognizes
bare names. `receiverOf` resolves index-selected receivers through their places,
while other receivers are evaluated once. `chosenByElement` follows member and
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

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[src/_MOC]] · [[Eval Call]]
