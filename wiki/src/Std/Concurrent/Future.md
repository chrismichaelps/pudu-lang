---
type: module
path: "@root/lib/Std/Concurrent/Future.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, concurrency]
aliases: [Std Concurrent Future]
---

# Std Concurrent Future

## Purpose and interface

A value another thread is producing, with waiting that never strands the waiter.

- `type Future[T]`.
- `start(action: fn() -> T) -> Result[Future[T], ConcurrentError]`.
- `promise[T]() -> Future[T]`, `fulfil(future, value) -> Bool`, `fail(future, problem) -> Bool`:
  a future settled by hand; the answer says whether this call settled it.
- `wait(future) -> Result[T, ConcurrentError]`: blocks until it settles.
- `isDone(future) -> Bool`.
- `waitWithin(future, millis)`, `waitUntil(future, token) -> Result[Option[T], ConcurrentError]`:
  `None` when the deadline passes or the token fires first.
- `waitAll(futures) -> Result[Array[T], ConcurrentError]`: every one waited for, the first
  failure in input order reported.
- `settleAll(futures) -> Array[Result[T, ConcurrentError]]`: every outcome, in input order.
- `race(token, actions)`: the first action to settle, success or failure.
- `firstSuccess(token, actions)`: the first action to succeed, or the first failure in input order
  when none does.
- `within(millis, action) -> Result[Option[T], ConcurrentError]`: the action's value, or `None`
  when its deadline passed first.

Race and deadline actions take a `Cancel.Token`, a child of the caller's, cancelled once the answer
is known.

## Semantics

- A future settles exactly once. Its work runs on a thread of its own, joined by a supervising
  thread that runs no caller code; only the supervisor writes the outcome. A crash in the work is
  therefore still a settlement (`Failed` with what the thread said), and a supervisor that cannot
  be started settles the future with the start failure itself.
- Settling writes the outcome under the future's lock and then closes its channel. `wait` blocks on
  that channel, so an untimed wait never polls; `waitWithin` and `waitUntil` poll `isDone` in
  slices of at most 10 milliseconds, and end because every future settles.
- A race gives every entrant one notification slot on a channel sized to the entrants, and every
  entrant is notified exactly once, whether it finished, crashed, or could not be started. The
  race reads notifications until it has its answer, cancels the rest through their tokens, and
  waits for every entrant before returning, so no thread outlives it.
- `within` does the same with one entrant: after the deadline it cancels the token and waits for the
  work to notice.

## Grill Log

- **Q:** Let the working thread write its own outcome? **A:** No. _Rationale:_ a thread that crashes
  never reaches the write, and a waiter on its channel would block forever; a crash is only visible
  to whoever joins the thread, so the joiner writes. _Rejected:_ outcome writes inside caller code.
- **Q:** Count a race entrant that failed to start? **A:** Yes, as settled with that failure and
  notified by the caller. _Rationale:_ a race waiting for a notification no thread will send never
  ends. _Rejected:_ dropping start failures.
- **Q:** Return the winner while losers still run? **A:** No. _Rationale:_ unjoined work outlives its
  caller's decision; losers are cancelled cooperatively and joined.

## Referenced by

[[src/Std/_MOC]] · [[Std Concurrent]] · [[Std Concurrent Pool]] · [[Uses Concurrent Futures]] · [[Uses Concurrent Coordination]]
