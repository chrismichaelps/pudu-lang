---
type: module
path: "@root/test-fixtures/stdlib/UsesConcurrentCoordination.pudu"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
tags: [module, fixture, stdlib, concurrency]
aliases: [Uses Concurrent Coordination]
---

# Uses Concurrent Coordination

## Purpose and interface

Executable Pudu fixture for worker pools, coordination primitives, and retry policies. Its `main`
returns 39 held assertions. Every check is written so its answer does not depend on which thread got
there first.

Pools: a worker count below one refused before anything starts; every submitted job run once, a
crashing job taking nothing else down, and shutdown reporting the crash; and a bounded queue holding
a producer back while the only worker is held, until that worker is released.

Coordination: a semaphore lending its permits and refusing one more release than it lent without
blocking; a crash inside a permit still returning the permit; one permit shared by four threads never
held by two at once; a latch waking every waiter together and opening at once for a count below one;
a wait group returning once its work is done and then refusing more, refusing an unmatched `done`,
and reporting an empty group idle; and a once running its initialiser a single time across racing
callers, with a crashing initialiser leaving it unset for the next caller.

Retry: backoff saturating at its cap instead of overflowing and never going negative for a policy that
would be refused; jitter staying under the ceiling, with equal jitter keeping at least half; and a
retry succeeding on a later attempt, giving up with the last failure, stopping for a failure it must
not retry, and refusing a bad policy.

## Grill Log

- **Q:** Prove backpressure by timing how long a submit blocks? **A:** No. _Rationale:_ the worker is
  held on a latch, so a full queue is a state the fixture sets up rather than a race it hopes to win.
  _Rejected:_ duration thresholds.

## Referenced by

[[Std Concurrent Pool]] · [[Std Concurrent Coordinate]] · [[Std Concurrent Retry]] · [[Std Concurrent]] · [[Runtime Evaluation Spec]]
