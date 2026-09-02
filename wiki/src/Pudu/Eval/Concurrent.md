---
type: module
path: "@root/src/Pudu/Eval/Concurrent.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
tags: [module, runtime, concurrency]
aliases: [Eval Concurrent]
---
# Eval Concurrent
## Purpose
Own one evaluation's host threads, bounded channels, mutexes, and atomic cells referenced by opaque
Pudu tokens.
## Interface
Registers/joins threads; creates and operates channels, mutexes, and cells; sleeps; and closes all
concurrency resources in that evaluation's store at teardown.
## Governance and algorithm
Tables use never-reused tokens. Channels use a `Seq`, so enqueue, dequeue, and pending-count remain
constant-time while STM enforces capacity and close conditions. A mutex records the owning host
thread; only that thread may release it, and an unlocked or foreign release is an `IoOutcome`
failure. Cell swaps are atomic and joined outcomes are replayable. Host exceptions become
`IoOutcome` failures at the evaluator boundary. Stores are isolated per evaluation, and teardown
cannot invalidate another embedded program's tokens.
## Grill Log
- **Q:** Copy host resources inside `Value`? **A:** No. _Rationale:_ copying identity-bearing
  resources would create multiple owners of one state. _Rejected:_ unbounded queues; swallowed worker
  failures; list-backed FIFO append; permissive double-unlock; claiming structured async equivalence.
- **Q:** Keep one process-global table? **A:** No. _Rationale:_ an evaluation owns only the workers
  and synchronization objects it created. _Rejected:_ global clearing at program exit.
## Referenced by
[[src/Pudu/Eval/_MOC]] · [[Std Concurrent]] · [[Std Channel]] · [[Std Sync]]
