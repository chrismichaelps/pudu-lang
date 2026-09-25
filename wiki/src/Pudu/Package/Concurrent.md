---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Package/Concurrent.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module, packages, concurrency]
aliases: [Package Concurrent]
---

# Package Concurrent

## Purpose and interface

`forConcurrently limit items work` runs each item on its own thread with at most `limit` at once (`concurrentLimit` is 8), answers the results in item order, and re-raises an item's exception in the caller only after every item finished, so no thread outlives the call.

See [[architecture/PACKAGES]].

## Grill Log

- **Q:** Unbounded threads? **A:** No, a semaphore of 8. _Rationale:_ each git fetch is a process and each copy holds open files. _Rejected:_ one thread per dependency.
- **Q:** Cancel the rest on the first failure? **A:** No, wait for all. _Rationale:_ a half-written checkout is discarded by its staging rename anyway, and waiting keeps the call free of stray threads. _Rejected:_ async cancellation.

Resolved Grill Log: behaviour covered by `test/Pudu/PackageSpec.hs`.
