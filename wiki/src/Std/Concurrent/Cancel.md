---
type: module
path: "@root/lib/Std/Concurrent/Cancel.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, concurrency]
aliases: [Std Concurrent Cancel]
---

# Std Concurrent Cancel

## Purpose and interface

Cooperative cancellation and deadlines. A running thread cannot be interrupted, so work holds a
`Token`, asks it between steps, and waits through `pause`, which returns as soon as the token fires.

- `type Reason = Requested(Str) | DeadlineExceeded`; `type Token`.
- `token()`, `expiring(millis)`: a root token, never firing by itself or firing `millis` from now.
- `child(parent)`, `childExpiring(parent, millis)`: stops when its parent stops; the child's
  deadline is the earlier of its own and its parent's.
- `cancel(token, why) -> Result[(), Sync.SyncError]`: stops the token and every child of it.
- `reason(token) -> Option[Reason]`, `stopped(token) -> Bool`, `check(token) -> Result[(), Reason]`.
- `remaining(token) -> Option[Int]`: milliseconds to the deadline, or `None` without one.
- `pause(token, millis) -> Result[(), Reason]`: sleeps, waking early with the reason.
- `explain(reason) -> Str`.

## Semantics

- A token is its own flag, the flags of every ancestor, and a deadline on the monotonic clock.
  Asking reads the ancestors first, so a parent's reason is the one a child reports.
- The first `cancel` of a token wins; a later one changes nothing. The check and the write happen
  under the token's lock, so two cancels cannot interleave into the later reason.
- A flag that cannot be read answers as stopped, with the read failure as its reason: work that
  cannot tell whether it should stop stops.
- `pause` sleeps in slices of at most 10 milliseconds and never past the deadline, so a cancel is
  noticed within one slice. This is the one place the concurrency modules poll, and it is bounded.

## Grill Log

- **Q:** Interrupt a blocked thread instead? **A:** Not in this slice. _Rationale:_ the runtime
  offers no interruption primitive and #330 builds on the existing primitives only; a token that
  every wait in these modules honours covers work written against them. _Rejected:_ describing
  preemptive cancellation the runtime does not perform.
- **Q:** Should stopping a child stop its parent? **A:** No. _Rationale:_ a race cancels its losers
  through children of the caller's token; the caller's own work continues.

## Referenced by

[[src/Std/_MOC]] · [[Std Concurrent]] · [[Std Concurrent Future]] · [[Std Concurrent Retry]] · [[Std Concurrent Scope]] · [[Uses Concurrent Futures]] · [[Uses Concurrent Coordination]]
