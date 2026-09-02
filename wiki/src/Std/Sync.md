---
type: module
path: "@root/lib/Std/Sync.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, synchronization]
aliases: [Std Sync]
---
# Std Sync
## Purpose
Provide runtime-owned mutual exclusion and atomic shared cells for thread coordination.
## Interface
Exports mutex/lock/unlock/withLock, typed cell read/swap/set, and a counter composed from them.
## Governance and algorithm
Tokens name runtime objects that cannot be fabricated through public constructors. Cell swap is
atomic; compound read-modify-write requires the mutex. A mutex is owned by the host thread that
acquired it, so an unlocked or foreign release fails instead of manufacturing an extra permit.
Failures remain `SyncError` values.
## Grill Log
- **Q:** Promise that separate read and set are atomic together? **A:** No. _Rationale:_ another
  thread may act between calls. _Rejected:_ exposing mutable host references as Pudu values.
- **Q:** Make repeated unlock idempotent? **A:** No. _Rationale:_ accepting it hides ownership bugs
  and can violate mutual exclusion. _Rejected:_ an ownerless binary permit.
## Referenced by
[[src/Std/_MOC]] · [[Eval Concurrent]] · [[architecture/STDLIB]]
