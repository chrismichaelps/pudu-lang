---
type: module
path: "@root/test-fixtures/stdlib/UsesConcurrent.pudu"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
tags: [module, fixture, stdlib, concurrency]
aliases: [Uses Concurrent]
---

# Uses Concurrent

## Purpose and interface

Executable Pudu fixture for threads, channels, locks, cells, and bounded parallel work. Its `main`
returns 41 held assertions. Every check is written so its answer does not depend on which thread got
there first.

Threads and sharing: a producer and consumer across a closing channel, four adders over one counter,
joins that answer the same way twice, and bounded parallel execution and mapping that keep input order
and report typed failures.

Cancellation and scopes: a sleeping thread cancelled and reporting `Cancelled` when joined; cancelling a
finished thread changing nothing; cancelling an unknown token answering `Missing`; a scope joining the
work of three threads; a scope whose body fails cancelling a sleeping child before it acts; a scope
reporting a child's panic; a deadline answered in time; a deadline overrun and cancelled; and a deadline
that is not positive refused.

## Referenced by

[[Std Concurrent]] · [[Runtime Evaluation Spec]]
