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
`receiveUntil` rejects an empty marker or a limit shorter than the marker before reading, counts the
marker inside the limit, and never asks for more than the limit leaves, so a marker past the limit is
an error rather than an answer. `receiveExactly` rejects a negative count and asks for at most one
chunk per read: a length taken off the wire sizes the answer, never a single receive buffer.
## Grill Log
- **Q:** Make `receiveAll` the primary API? **A:** No. _Rationale:_ it lets the peer select caller
  memory. _Rejected:_ inventing success on partial exact reads; leaking host exceptions.
- **Q:** Treat a timeout as a generic socket failure? **A:** No. _Rationale:_ callers retry and
  report it differently from refusal, closure, and resolution failure. _Rejected:_ message matching
  outside this module.
- **Q:** Let `receiveUntil` read a full chunk and check the limit only while the marker is missing?
  **A:** No. _Rationale:_ one read then carries a marker far past the limit and the limit bounds
  nothing. _Rejected:_ trimming after the fact, which still buffers the overshoot.
- **Q:** Ask the host for the whole remaining count in `receiveExactly`? **A:** No. _Rationale:_ the
  runtime allocates the requested size per read, so a peer's length prefix would choose the
  allocation. _Rejected:_ trusting the prefix.
- **Q:** Search the whole buffer and concatenate onto it after every chunk? **A:** No. _Rationale:_
  waiting for a marker 32 MB in took 8.99 s and grew with the square of the bytes (#411). Each
  chunk is searched with the carried bytes that could begin a marker (`tailStart`), and the
  chunks are joined once. An empty read is a close rather than a reason to read again.
## Referenced by
[[src/Std/_MOC]] · [[Eval Socket]] · [[architecture/STDLIB]]
