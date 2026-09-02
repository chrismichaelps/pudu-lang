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
Exports listen/connect/accept, peer/port inspection, send/receive/finish/close, bounded marker and
exact reads, chunk folds, scoped connection use, and bounded serving.
## Governance and algorithm
Sockets are runtime-owned tokens. A single send is completed fully; EOF differs from an empty read;
buffering helpers carry explicit limits and return remainders instead of discarding the next message.
## Grill Log
- **Q:** Make `receiveAll` the primary API? **A:** No. _Rationale:_ it lets the peer select caller
  memory. _Rejected:_ inventing success on partial exact reads; leaking host exceptions.
## Referenced by
[[src/Std/_MOC]] · [[Eval Socket]] · [[architecture/STDLIB]]
