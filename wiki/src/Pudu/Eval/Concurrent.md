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

## Bounded channel waits

`channelReceiveWithin` validates mathematical token and millisecond values before narrowing.
Its nested optional outcome denotes timeout, closed-empty or a delivered value. An atomic probe
avoids allocating a timer for ready, closed or zero-wait calls. Empty positive waits create one
private timer, bracket its lifetime and atomically select an available value, closure or expiry.
Queued values and closure precede expiry; timeout performs no dequeue. Interruption releases the
timer. No timer enters the evaluation's resource registries.
Resolved Grill Log: bound multiplication before delay conversion; release timers after every
outcome; retain ordinary blocking receive and reuse the same atomic queue probe.

## Explicit disposal

`cellDispose` retires its holder before removing it; later reads and swaps fail. `mutexDispose`
requires an unowned lock, retires its state before removal and wakes admitted waiters to refusal.
`threadForget` removes only completed outcomes; replayable joining remains unchanged beforehand.
Unknown and repeated disposal fail. Tokens are never reused. Mask the retirement/removal phase
against interruption. `concurrentCounts` exposes quiescent table sizes for runtime regression tests.
Resolved Grill Log: retire before removal to close admitted-operation races; refuse active owners.
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
failure. Cell swaps are atomic and joined outcomes are replayable. No public primitive interrupts
an active thread; explicit forgetting refuses it. Blocking runtime waits are interruptible during
evaluation teardown, while a call held inside foreign code stops only once it returns. Host exceptions become
`IoOutcome` failures at the evaluator boundary. Stores are isolated per evaluation, and teardown
cannot invalidate another embedded program's tokens. Teardown stops remaining threads through
`trySynchronous` from [[Eval Io]], so an interrupt arriving while threads are stopped still ends the
program rather than being absorbed as a failed stop.
## Grill Log
- **Q:** Copy host resources inside `Value`? **A:** No. _Rationale:_ copying identity-bearing
  resources would create multiple owners of one state. _Rejected:_ unbounded queues; swallowed worker
  failures; list-backed FIFO append; permissive double-unlock; claiming structured async equivalence.
- **Q:** Keep one process-global table? **A:** No. _Rationale:_ an evaluation owns only the workers
  and synchronization objects it created. _Rejected:_ global clearing at program exit.
## Referenced by
[[src/Pudu/Eval/_MOC]] · [[Std Concurrent]] · [[Std Channel]] · [[Std Sync]] · [[Eval System Tests]]

## Bounded mutex admission (#476)

mutexLockWithin validates mathematical token and duration before narrowing: 0 through 3600000 milliseconds. A shared atomic probe acquires an available mutex, refuses its current owner or retired state, and waits only for another owner. Ordinary acquisition uses the same probe. Expiry changes no ownership; admission precedes expiry atomically. Ready and zero waits allocate no timer. The private bracketed timer helper also preserves channel dequeue/closure precedence and retires on completion or interruption.
Resolved Grill Log: recursive ownership is a refusal, never a retry; bound admission without canceling an admitted callback. Preserve owner-only release and retirement races. [[Mutex Admission Spec]] proves these boundaries.

## Joined scope retirement (#480)

mutexClose validates the mathematical token, stops admission atomically, and joins an existing foreign owner. Closing retains that owner identity; only its release may complete retirement. Unowned close retires immediately. Self-owned close refuses before state change. New/parked acquisition sees Missing. Owner release masks retirement/removal so a canceled closer cannot retain a completed registration. Disposal continues to refuse held or closing locks. Unknown/repeated close refuses. Resolved Grill Log: close admission before joining; preserve owner-only release; never force-release admitted work.
