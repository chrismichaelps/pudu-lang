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
Listens, accepts, connects with an optional operation timeout, sends all bytes and receives bounded
chunks with the same option, half-closes, inspects peer/local port, closes one socket, and closes the
remaining sockets in that evaluation's store.
## Governance and algorithm
Opaque never-reused tokens preserve resource identity inside a store; resolver and socket exceptions
never cross the language boundary; send loops until complete and receive distinguishes EOF. Stores
are isolated per evaluation. A non-negative timeout interrupts DNS/connect/send/receive using the
host runtime's timer, reports the stable phrase `operation timed out`, and lets acquisition brackets
close any socket not yet installed in the store. A negative value retains the unbounded primitive
used by `Std.Net`'s low-level forms. A timed-out send or receive closes and forgets the endpoint:
the peer may already have received a prefix, so no later operation can safely resume that stream.
## Grill Log
- **Q:** Parse numeric addresses in Pudu? **A:** No. _Rationale:_ host resolution owns names,
  address families, and machine configuration. _Rejected:_ one-write send; stale token reuse.
- **Q:** Use one process-global socket table? **A:** No. _Rationale:_ one program ending must not
  close another program's listener. _Rejected:_ global teardown.
- **Q:** Set a process-wide or socket-wide timeout? **A:** No. _Rationale:_ one operation's budget
  must not alter another operation on the same runtime resource. _Rejected:_ ambient timeout state.
## Referenced by
[[src/Pudu/Eval/_MOC]] · [[Std Net]] · [[Eval Effect]]


## TLS and binary compression implementation contract

takeSocket atomically removes a plain socket token for exclusive transfer into TLS. The caller owns cleanup after transfer; old tokens cannot initiate further operations. Callers must not race upgrade with in-flight plain operations.

Resolved Grill Log: protocol bytes must remain bytes; verified transport cannot downgrade. Errors remain explicit and resource ownership transfers once. Implementation is code-only; no validation or readiness claim.

## Low-latency TCP socket configuration

TCP endpoints accepted via `acceptOn` and dialed via `connectToWithin` configure `TCP_NODELAY` (`Net.NoDelay = 1`) by default. This disables Nagle's algorithm, preventing the operating system TCP stack from withholding partial frames while waiting for delayed ACKs (the 1–2 ms latency penalty on loopback and interactive RPC/HTTP request-response exchanges). Non-TCP endpoints (such as Unix domain sockets) safely ignore options that do not apply to their address family.

Resolved Grill Log: interactive network protocols require immediate packet dispatch; buffering small response heads behind delayed ACKs degrades latency by orders of magnitude without improving loopback throughput.

