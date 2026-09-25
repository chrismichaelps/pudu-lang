---
type: module
path: "@root/test-fixtures/stdlib/UsesConcurrentScope.pudu"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
tags: [module, fixture, stdlib, concurrency]
aliases: [Uses Concurrent Scope]
---

# Uses Concurrent Scope

## Purpose and interface

Executable Pudu fixture for [[Std Concurrent Scope]]. Its `main` returns 7 held assertions: values
answered in input order; an empty scope; a typed failure cancelling a sibling that would otherwise
wait forever; a crash doing the same and answered as `Crashed`; a cancelled parent reaching every
action; every action finished when `all` returns; and the failure that caused the cancellation kept
over one an earlier action returns after noticing it.

## Grill Log

- **Q:** Prove cancellation with a sibling that sleeps a long time? **A:** No. _Rationale:_ a sleep
  only makes the check likely. _Accepted:_ the sibling waits on its token with no deadline, so the
  scope can only return if the failure cancelled it.

## Referenced by

[[Std Concurrent Scope]] · [[Runtime Evaluation Spec]]
