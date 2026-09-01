---
type: module
path: "@root/src/Pudu/Eval/Socket.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
tags: [module, runtime, network]
aliases: [Eval Socket]
---
# Eval Socket
## Purpose
Own one evaluation's TCP sockets and translate resolver/socket operations into typed evaluator outcomes.
## Interface
Listens, accepts, connects, sends all bytes, receives bounded chunks, half-closes, inspects peer/local
port, closes one socket, and closes the remaining sockets in that evaluation's store.
## Governance and algorithm
Opaque never-reused tokens preserve resource identity inside a store; resolver and socket exceptions
never cross the language boundary; send loops until complete and receive distinguishes EOF. Stores
are isolated per evaluation.
## Grill Log
- **Q:** Parse numeric addresses in Pudu? **A:** No. _Rationale:_ host resolution owns names,
  address families, and machine configuration. _Rejected:_ one-write send; stale token reuse.
- **Q:** Use one process-global socket table? **A:** No. _Rationale:_ one program ending must not
  close another program's listener. _Rejected:_ global teardown.
## Referenced by
[[src/Pudu/Eval/_MOC]] · [[Std Net]] · [[Eval Effect]]
