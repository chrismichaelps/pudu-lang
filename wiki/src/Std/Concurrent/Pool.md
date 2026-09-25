---
type: module
path: "@root/lib/Std/Concurrent/Pool.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, concurrency]
aliases: [Std Concurrent Pool]
---

# Std Concurrent Pool

## Purpose and interface

A fixed set of workers draining a bounded queue, so producers are slowed to the workers' pace.

- `type Pool`.
- `pool(workers, queue) -> Result[Pool, ConcurrentError]`.
- `submit(pool, job: fn() -> ()) -> Result[(), ConcurrentError]`: waits while the queue is full.
- `submitFor(pool, job: fn() -> T) -> Result[Future[T], ConcurrentError]`: a future of the job's
  value.
- `queued(pool) -> Result[Int, ConcurrentError]`, `size(pool) -> Int`.
- `shutdown(pool) -> Result[(), ConcurrentError]`: refuses further jobs, runs every queued job,
  joins every worker, and reports the first crash of a job submitted without a future.

## Semantics

- A worker never runs a job on its own thread: it starts the job on a thread of its own and joins
  it. A crashing job therefore ends only that job; the worker records the crash (in the job's
  future, or for a plain job in the pool's first-crash record) and takes the next job.
- `pool` starts every worker or none: when a later worker cannot be started, the queue is closed
  and the workers already started are joined before the failure is returned.
- Worker and queue counts below one are refused before anything starts.

## Grill Log

- **Q:** Run jobs directly on the worker thread? **A:** No. _Rationale:_ a crash would end the
  worker, strand every later job, and leave the job's future unsettled. _Rejected:_ it saves one
  thread start per job, which is small beside a stranded queue.
- **Q:** Offer a non-waiting `offer`? **A:** No. _Rationale:_ a channel has no send that refuses
  when full, and checking the length before sending lets another producer fill the slot between
  the two, so an `offer` could block despite its promise. _Rejected:_ a length check before `send`.

## Referenced by

[[src/Std/_MOC]] · [[Std Concurrent]] · [[Uses Concurrent Coordination]]
