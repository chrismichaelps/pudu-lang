---
type: module
path: "@root/lib/Std/Concurrent/Coordinate.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, concurrency]
aliases: [Std Concurrent Coordinate]
---

# Std Concurrent Coordinate

## Purpose and interface

Semaphores, latches, wait groups, and run-once values.

- `type CoordinateError = Closed | Overreleased | Finished | Failed(ConcurrentError) | Other(Str)`.
- `semaphore(permits)`, `acquire`, `release`, `available`, `withPermit(semaphore, action)`.
- `latch(count)`, `countDown`, `isOpen`, `waitLatch`, `waitLatchWithin(latch, millis) -> Result[Bool, CoordinateError]`.
- `waitGroup()`, `add(group, count)`, `done(group)`, `waitGroupDone(group)`.
- `once[T]()`, `resolve(once, init: fn() -> T) -> Result[T, CoordinateError]`, `peek(once) -> Option[T]`.
- `explain(problem) -> Str`.

## Semantics

- A semaphore is a channel holding its free permits and a count of permits out. `release` lowers the
  count first and refuses with `Overreleased` when nothing is out, so the channel always has room for
  the permit it returns and a release never blocks.
- `withPermit` runs its action on a thread of its own and releases the permit whether the action
  returned or crashed; a crash answers `Failed`.
- A latch closes its channel when its count reaches zero, which wakes every waiter at once; counting
  down an open latch changes nothing.
- A wait group closes when its count returns to zero, or at once when waited on with nothing added.
  After that, `add` answers `Finished`; `done` without a matching `add` answers `Overreleased`.
- `resolve` runs `init` at most once to completion, under a lock, on a thread of its own: a crash
  answers `Failed`, releases the lock, and leaves the value unset for the next caller.

## Grill Log

- **Q:** Trust callers to release only what they acquired? **A:** No. _Rationale:_ an extra release
  into a full bounded channel blocks forever. _Rejected:_ an unguarded `send`.
- **Q:** Run guarded actions inline? **A:** No. _Rationale:_ a crash inside `withPermit` or `resolve`
  would keep a permit or a lock forever, and every later caller would wait on it.

## Referenced by

[[src/Std/_MOC]] · [[Std Concurrent]] · [[Uses Concurrent Coordination]]
