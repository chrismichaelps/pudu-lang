---
type: module
path: "@root/test/Pudu/Eval/SystemSpec.hs"
fidelity: Active
tags: [test, evaluation, resources]
aliases: [Eval System Tests]
---
# Eval System Tests

Bounded channel cases cover immediate probes, ready and closed queues, invalid waits and tokens,
timeout followed by successful receipt, parked delivery and closure, and competing consumers.
Source cases require exact nested option results and E7009 during constant evaluation.
Wrong argument type reports E3001; wrong arity reports E3003. Parked receivers expose private
timer identities and require retirement after delivery, closure and interruption. Removing timer
cleanup must fail all three cases. Twenty competing-receiver and twenty delivery/expiry cases
assert item conservation without requiring one scheduling order.
Resolved Grill Log: bound test joins independently so a stranded waiter fails visibly; assert
conservation of queued payloads and quiescent registry counts.

## Purpose and interface

Focused evaluator properties cover exact failure diagnostics, cold asynchronous calls, borrowing,
unsafe regions, scoped children, clock and subprocess outcomes, effect refusal during constant
evaluation and isolation of runtime stores. [[Eval Test Coordinator]] registers the executed cases.

## Resource disposal algorithm

Direct runtime cases check registry counts before and after repeated cell/mutex allocation and
disposal, no token reuse, retired-operation refusal, owned-mutex refusal and live-thread refusal.
Completed joins replay before forgetting and fail afterward. Stores remain isolated. Source cases
require E7009 for disposal during constant evaluation. No capacity or formal lifetime guarantee is
inferred from these tests.

A contender parks on an owned mutex before unlock races retirement. Either it acquires and releases
before successful disposal, or observes the retired token. A bounded wait detects stranded entrants;
quiescent counts must return to zero after both outcomes.

## Resolved Grill Log

- **Q:** Infer disposal from an operation refusing a token? **A:** No; also assert exact table counts.
- **Q:** Register only an unused local property list? **A:** No; register with the executable coordinator.

## Referenced by

[[Eval Test Coordinator]] · [[Eval Concurrent]] · [[src/_MOC]]
