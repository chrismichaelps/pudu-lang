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

`disposeCell` and `disposeMutex` release runtime registrations explicitly. Cells retire immediately;
mutexes must be unowned. Copied tokens also become invalid and unknown/repeated disposal is Missing.
Resolved Grill Log: disposal is separate from unlock and from value replacement.
## Purpose
Provide runtime-owned mutual exclusion and atomic shared cells for thread coordination.
## Interface
Exports mutex/lock/unlock/withLock, typed cell read/swap/set, explicit mutex/cell disposal and a
counter composed from them.
## Governance and algorithm
Tokens name runtime objects; fabricated unknown tokens are refused. Cell swap is
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

## Finite admission (#476)

LockAttempt[T] = Acquired(T) | LockExpired distinguishes a completed optional value from expiry. MAX_WAIT_MILLISECONDS is 3600000. lockWithin takes a validated 0..maximum duration; zero probes immediately. withLockWithin runs no action after expiry, releases after normal action return and retains typed failures as values. Recursive acquisition returns Other without releasing the original owner. Unknown/disposed tokens return Missing.
Resolved Grill Log: neither callback execution nor cleanup is timed; runtime abort and cancellation cleanup remain a separate recovery contract. Existing withLock also releases only after normal return. [[Mutex Admission Spec]] exercises the real public wrappers.

## Joined scope retirement (#480)

closeMutex(target) closes admission and waits for the existing owner to release before retiring the token. Missing covers unknown, closing and retired identities; closing from the current owner returns Other without altering ownership. The joining caller may be interrupted, but the existing owner still retires the registration on release. Resolved Grill Log: distinguish joining close from immediate disposal; no admitted work is canceled or force-released.
