---
type: module
path: "@root/lib/Std/Net.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, network]
aliases: [Std Net]
---
# Std Net
## Purpose
Expose TCP listeners and connections with typed host failures and streaming-first reads.
## Interface
Exports listen/connect/accept, deadline-bounded connect/send/receive variants, peer/port inspection,
send/receive/finish/close, bounded marker and exact reads, chunk folds, scoped connection use, and
bounded serving.
## Governance and algorithm
Sockets are runtime-owned tokens. A single send is completed fully; EOF differs from an empty read;
buffering helpers carry explicit limits and return remainders instead of discarding the next message.
The `Within` operations bound one blocking host operation in milliseconds, preserve the unbounded
forms for low-level protocols that own another cancellation mechanism, and report
`NetOperationTimedOut` as a cause distinct from refusal or resolution failure.
When send or receive times out, the connection is closed and cannot be reused; partial delivery is
possible and retry policy belongs to the protocol above this module.
## Grill Log
- **Q:** Make `receiveAll` the primary API? **A:** No. _Rationale:_ it lets the peer select caller
  memory. _Rejected:_ inventing success on partial exact reads; leaking host exceptions.
- **Q:** Treat a timeout as a generic socket failure? **A:** No. _Rationale:_ callers retry and
  report it differently from refusal, closure, and resolution failure. _Rejected:_ message matching
  outside this module.
## Referenced by
[[src/Std/_MOC]] · [[Eval Socket]] · [[architecture/STDLIB]]
