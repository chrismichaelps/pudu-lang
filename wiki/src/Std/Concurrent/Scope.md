---
type: module
path: "@root/lib/Std/Concurrent/Scope.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, concurrency]
aliases: [Std Concurrent Scope]
---

# Std Concurrent Scope

## Purpose and interface

Sibling tasks that succeed together or not at all, and never outlive the call that started them.

- `type ScopeError[E] = Failed(E) | Crashed(ConcurrentError)`: an action's own failure, or a crash
  (including a thread that could not be started).
- `all(parent, actions: Array[fn(Cancel.Token) -> Result[T, E]]) -> Result[Array[T], ScopeError[E]]`:
  runs every action on its own thread with one child token of `parent`, and answers every value in
  input order, or the first failure seen.

## Semantics

- The first failure, `Err` or a crash, cancels the shared token with the reason "a sibling failed",
  so every other action that consults its token stops. Cancellation is cooperative: an action that
  never looks at its token runs to its end.
- `all` answers only after every started action has finished, whatever the outcome, so no thread
  it started is still running when it returns.
- Cancelling `parent` reaches every action through the child token; the scope then answers whatever
  the actions return.
- When a thread cannot be started, the actions already started are cancelled and waited for, and
  the start failure is answered as `Crashed`.
- "First failure seen" is the first the scope observes while it watches its actions; when two fail
  in the same interval, the earlier in input order is answered.
- An empty scope answers `Ok([])` at once.

## Grill Log

- **Q:** Let `all` return as soon as one action fails? **A:** No. _Rationale:_ a scope's promise is
  that nothing it started outlives it; returning early leaves siblings writing to shared state after
  the caller moved on. _Rejected:_ fire-and-forget cancellation.
- **Q:** Take actions returning plain values, and treat only crashes as failure? **A:** No.
  _Rationale:_ ordinary failures are typed `Result`s in Pudu; a scope that only noticed crashes
  would let a failed step's siblings keep working. _Accepted:_ `Result[T, E]` actions and
  `ScopeError[E]` keeping the two kinds apart.
- **Q:** Report the failure that happened first in wall time? **A:** Only as far as it can be
  observed. _Rationale:_ the scope sees failures by watching settled futures, so two failures inside
  one watch interval are ordered by input position, which keeps the answer deterministic.

## Referenced by

[[src/Std/_MOC]] · [[Std Concurrent]] · [[Std Concurrent Future]] · [[Uses Concurrent Scope]]
