---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Type/Frontier.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, performance, literals]
aliases: [Type Literal Frontier]
---

# Type Literal Frontier

## Purpose and interface

Select pending facts by a monotone creation frontier without traversing older
unrelated facts. `splitSince :: (a -> Int) -> Int -> [a] -> ([a], [a])` returns the
recent prefix and retained older suffix. `splitBetween` takes lower/upper bounds
and returns the selected interval and retained queue. Both preserve newest-first
ordering; the caller owns whether selected work executes in source order.

## Algorithm and invariant

Input creation identities decrease strictly from head to tail. A since query is
one prefix span and shares the older suffix. An interval query skips the newer
prefix, extracts the selected prefix and reconnects newer facts to the shared
older suffix. Empty/reversed intervals return the original queue. Complexity is
proportional to recent/selected work, independent of the older queue length.
This is the pending integer-literal invariant of [[Type Env]]: fresh identities
increase monotonically, insertion prepends, selection and negation retain order.

## Edge cases and negative logic

Gapped creation identities, empty selections and an unrelated older suffix are
valid. Neither function sorts, walks the entire queue, changes payloads, decides
numeric types or defaulting, or owns checker state. Older payloads are not forced.
The first older identity is inspected to identify the boundary; its tail stays
shared. Do not apply these functions to unsorted arbitrary lists.

## Grill Log

- **Q:** Partition every pending literal for every branch? **A:** No; use its
  known descending creation order. _Rationale:_ whole-queue selection allocates
  quadratically when siblings leave literals for their enclosing annotation.
  _Rejected:_ sorting each query or eager whole-body numeric defaulting.
- **Q:** Reverse all retained facts? **A:** No. _Rationale:_ the ordered suffix is
  shared across queries and preserves inference timing. _Rejected:_ rebuilding
  older state to remove a recent prefix.

## Referenced by

[[Type Env]] · [[Type Literal Frontier Spec]] · [[src/Pudu/Type/_MOC]]
