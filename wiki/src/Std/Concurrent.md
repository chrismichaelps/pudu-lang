---
type: module
path: "@root/lib/Std/Concurrent.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, concurrency]
aliases: [Std Concurrent]
---
# Std Concurrent
## Purpose
Expose runtime threads as joinable task handles for blocking host work.
## Interface
Exports start, join, join-all, parallel execution, and duration-based sleep results.
## Governance and algorithm
Every started task has a runtime token and an observable join result; worker failure becomes
`ConcurrentError`. This host-thread surface does not redefine Pudu async task-tree semantics.
## Grill Log
- **Q:** Treat these handles as detached fire-and-forget work? **A:** No. _Rationale:_ unjoined work
  leaks lifetime and failure. _Rejected:_ silent thread exceptions; claiming scheduler fairness.
## Referenced by
[[src/Std/_MOC]] · [[Eval Concurrent]] · [[architecture/SEMANTICS]]

## Bounded batch execution

parallelBounded(actions, workers) starts at most min(workers, actions.length) threads; a shared
atomic counter assigns each action index once. forEachBounded applies the same scheduler to
values through action closures. Invalid worker counts return Other before starting work; empty
batches succeed for a valid count. Each started worker is joined, including after a later start
failure. Join errors follow worker-start order. Failed actions can abort their worker; remaining
workers continue claiming work, and join reports the failure. Completion is not claimed after
any start/join failure. There is no cancellation, deadline or guaranteed action completion order.
All actions execute at most once per call; these functions do not retry failures.

Resolved Grill Log: use a counter rather than a blocking producer queue so failed workers cannot
strand a producer on queue admission. Input closures still occupy O(n) storage; concurrency and
retained task handles are O(min(n,workers)). Workers stop through typed counter failures rather
than silently repeating an index. No tests, builds or reviews run.

## Bounded parallel mapping

mapBounded(items, workers, transform) applies a transform with at most min(workers, items.length)
concurrent threads, populating preallocated indexed synchronization cells to guarantee results are
collected in exact input order regardless of task completion timing. Unwritten slots or worker
panics surface as typed ConcurrentError. mapResultBounded evaluates fallible transforms, returning
the first application error in input order while retaining host ConcurrentError observation.

Resolved Grill Log:
- **Q:** How are results ordered without sorting or synchronization contention? **A:** Each item is
  assigned an isolated slot cell before thread scheduling. Workers write strictly to their own slot
  index; results are gathered sequentially from slot 0 to N-1 after joinAll.
- **Q:** How are fallible transforms handled? **A:** Both pure and fallible mapping are supported:
  mapBounded collects arbitrary typed values U, while mapResultBounded unpacks Result[U, E] to
  preserve the first typed failure in input order.
