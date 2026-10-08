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
`receiveWithin(source, waitMillis)` returns `Result[Receive[T], ChannelError]`, where `Receive[T]`
is `Received(T) | Finished | TimedOut`. Zero probes immediately. Negative or unrepresentable
millisecond waits return `Other("invalid channel wait")`; existing receive behavior is unchanged.
## Bounded receive contract
Ready values precede closure and timeout. Closed channels drain their queued values first.
Timeout consumes nothing, changes no channel state and permits a later receive. Optional payloads
remain distinct from closure. This bounds admission waiting, not work performed after admission.
Resolved Grill Log: select queue removal and expiry atomically; never interrupt a consumer after
it has removed an item. The runtime owns and releases each wait timer.
## Governance and algorithm
Receive distinguishes closed-and-empty from a value; close preserves queued values; send to a
closed channel is a typed error. Capacity is always positive.
## Grill Log
- **Q:** Make channels unbounded by default? **A:** No. _Rationale:_ a faster producer would turn a
  slower consumer into unbounded memory. _Rejected:_ dropping sends after close.
## Referenced by
[[src/Std/_MOC]] · [[Eval Concurrent]] · [[architecture/STDLIB]]
