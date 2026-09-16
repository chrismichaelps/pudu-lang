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

## Cancellation, scopes, and deadlines

`cancel(worker)` stops a thread wherever it is, including while it sleeps or waits on a channel, and
answers only once the thread has stopped, so anything it was using may be released afterwards. Joining
a cancelled thread answers `Cancelled`; cancelling a thread that already finished changes nothing, and
cancelling a token that names no thread answers `Missing`. A thread is started masked and unmasked only
inside the handler that records its outcome, so a thread cancelled before its body begins still reports,
and a join after a cancellation cannot wait forever.

`scope(body)` gives a body a `Scope` to start threads into with `spawnIn`. Threads are recorded under a
lock, so threads started into one scope from several threads are all kept. When the body succeeds, every
thread is joined in start order and the first failure among them is the answer; when the body fails,
every thread still running is cancelled and the body's failure is the answer. No thread started into a
scope keeps running after `scope` returns.

`withDeadline(millis, action)` races the action against a timer on two threads and cancels the loser. An
action that answers in time answers its value, one that overruns answers `DeadlineExceeded(millis)`, one
that failed before the deadline answers its failure, and a deadline below one millisecond is refused.

Blocking waits inside the runtime are interruptible, so cancellation reaches sleeps, channel waits, and
socket and file reads; a call held inside foreign code is not interrupted until it returns.

Resolved Grill Log:
- **Q:** Leave cancellation cooperative, with threads polling a flag? **A:** No. _Rationale:_ a thread
  blocked in a sleep or a wait never reaches a poll, which is exactly the thread a caller needs to stop.
  _Rejected:_ polling flags as the only mechanism.
- **Q:** Keep running children when a scope's body fails? **A:** No. _Rationale:_ their results have no
  consumer once the body has given up, and running on holds resources past the work's end. _Rejected:_
  detached children.
- **Q:** Report every child failure from a scope? **A:** The first, in start order. _Rationale:_ the same
  deterministic rule `joinAll` uses. _Rejected:_ completion-order reporting.
