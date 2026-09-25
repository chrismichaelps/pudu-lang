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
returns 32 held assertions. Every check is written so its answer does not depend on which thread got
there first.

Threads and sharing: a producer and consumer across a closing channel, four adders over one counter,
joins that answer the same way twice, and bounded parallel execution and mapping that keep input order
and report typed failures.

Cancellation, deadlines, and crash containment are covered by [[Uses Concurrent Futures]] and
[[Uses Concurrent Coordination]], over the modules under [[Std Concurrent]].

## Referenced by

[[Std Concurrent]] · [[Runtime Evaluation Spec]]
