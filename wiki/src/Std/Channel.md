---
type: module
path: "@root/lib/Std/Channel.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, channel]
aliases: [Std Channel]
---
# Std Channel
## Purpose
Move typed values between runtime threads with bounded back-pressure and explicit closure.
## Interface
Exports channel creation, blocking send/receive, pending count, close, fold, and drain.
## Governance and algorithm
Receive distinguishes closed-and-empty from a value; close preserves queued values; send to a
closed channel is a typed error. Capacity is always positive.
## Grill Log
- **Q:** Make channels unbounded by default? **A:** No. _Rationale:_ a faster producer would turn a
  slower consumer into unbounded memory. _Rejected:_ dropping sends after close.
## Referenced by
[[src/Std/_MOC]] · [[Eval Concurrent]] · [[architecture/STDLIB]]
