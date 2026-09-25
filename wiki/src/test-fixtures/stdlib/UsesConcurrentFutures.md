---
type: module
path: "@root/test-fixtures/stdlib/UsesConcurrentFutures.pudu"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
tags: [module, fixture, stdlib, concurrency]
aliases: [Uses Concurrent Futures]
---

# Uses Concurrent Futures

## Purpose and interface

Executable Pudu fixture for crash containment, cancellation tokens, and futures. Its `main` returns 30
held assertions. Every check is written so its answer does not depend on which thread got there first.

Containment and tokens: a contained crash answered as `Failed` and a clean action answered `Ok`; a
fresh token that has not fired and has no deadline; a cancelled token keeping its first reason;
deadlines that fire by themselves, with a child keeping its parent's earlier deadline; and a pause
that ends when its time is up or early when its token fires.

Futures: a value answered, and a crash in the work still settling the future, so a wait on a token
with no deadline ends; a promise settling once and keeping its first outcome; a bounded wait giving
up without disturbing the work; all-settled keeping every outcome in input order and wait-all
reporting the first failure; a race answering the first to settle and waiting for the loser to
notice; first-success skipping an earlier failure, and answering the first failure in input order
when nothing succeeds; and a deadline answering `None` once the work has noticed, while quick work
answers its value.

## Grill Log

- **Q:** Assert on which entrant of a race finished first? **A:** Only where one entrant cannot
  finish until the other has settled. _Rationale:_ a check that depends on scheduling passes on one
  machine and fails on another. _Rejected:_ sleeps chosen to make an ordering likely.

## Referenced by

[[Std Concurrent Future]] · [[Std Concurrent Cancel]] · [[Std Concurrent]] · [[Runtime Evaluation Spec]]
