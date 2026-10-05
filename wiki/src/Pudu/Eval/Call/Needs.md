---
type: module
path: "@root/src/Pudu/Eval/Call/Needs.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, runtime]
aliases: [Eval Call Needs]
---

# Eval Call Needs

## Purpose and interface

Own the dependency record tying calls back to expression, block and body execution.

## Algorithm and invariants

`CallNeeds` carries `callEvaluate :: Located Expression -> Evaluator Value`,
`callBlock :: Located Block -> Evaluator Value`, and
`callCompile :: [Text] -> FunctionBody -> Evaluator (Evaluator Value)`.
It contains no implementation behavior; [[Evaluator]] supplies the callbacks.

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
