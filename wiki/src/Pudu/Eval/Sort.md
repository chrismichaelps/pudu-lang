---
type: module
path: "@root/src/Pudu/Eval/Sort.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, runtime, sort, performance]
aliases: [Eval Sort]
---
# Eval Sort
## Purpose
Sort by a program's own comparison natively, so only the comparison runs through the evaluator and
the splitting, merging, and gathering do not.
## Interface
`sortWith before items` answers the items ordered by `before`, in any monad, keeping elements the
comparison calls equal in the order they arrived. [[Eval Builtin Array]] uses it for `sortBy`.
## Governance and algorithm
Natural merge sort. The input is cut into the runs it already holds: a stretch where no element goes
before the one ahead, or a strictly descending stretch, which is turned around (only a strict one may
be, or equal elements would swap). Runs merge in adjacent pairs, round after round; a right element
moves ahead only when it goes strictly before, which is what keeps the sort stable. Every loop
gathers into an accumulator, so the stack stays flat however long the runs are. Ordered or reversed
input costs one pass.
## Grill Log
- **Q:** Keep sorting in Pudu? **A:** No. _Rationale:_ every slice, push, and merge step was
  interpreted; 100,000 integers took 38.7 s on the development build and about 7 s after, most of it
  the comparisons themselves. _Rejected:_ a faster merge written in Pudu, which keeps the overhead.
- **Q:** Sort with the host's pure sort? **A:** No. _Rationale:_ the comparison is a program function
  that can fail or perform effects, so it must run in the evaluator's monad. _Rejected:_ calling the
  evaluator unsafely from pure code.
## Referenced by
[[src/Pudu/Eval/_MOC]] · [[Eval Builtin Array]] · [[Std List]]
