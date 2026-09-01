---
type: module
path: "@root/lib/Std/Concurrent.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, concurrency]
aliases: [Std Concurrent]
---
# Std Concurrent
## Purpose
Expose runtime threads as joinable task handles for blocking host work.
## Interface
Exports start, join, join-all, parallel execution, and duration-based sleep results.
## Governance and algorithm
Every started task has a runtime token and an observable join result; worker failure becomes
`ConcurrentError`. This host-thread surface does not redefine Pudu async task-tree semantics.
## Grill Log
- **Q:** Treat these handles as detached fire-and-forget work? **A:** No. _Rationale:_ unjoined work
  leaks lifetime and failure. _Rejected:_ silent thread exceptions; claiming scheduler fairness.
## Referenced by
[[src/Std/_MOC]] · [[Eval Concurrent]] · [[architecture/SEMANTICS]]
