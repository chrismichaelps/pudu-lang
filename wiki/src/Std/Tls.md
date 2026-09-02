---
type: module
path: "@root/lib/Std/Tls.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, network, security]
aliases: [Std Tls]
---
# Std Tls
## Purpose
Carry bytes over a connection whose contents only the two ends can read, to a host that has proved
it is the host that was named.
## Interface
`connect` and `withConnection` open one; `send`, `sendText`, `receive`, `receiveAll`,
`receiveUntil`, and `foldChunks` move bytes; `peerOf` answers the proven name; `close` ends it.
## Governance and algorithm
The protocol is not implemented here and not implemented in Pudu. Transport security is the one
place in this library where being wrong is silent: a handshake that skips a check still completes
and still carries traffic. [[Eval Tls]] therefore reaches an implementation that has been reviewed
and attacked for years, exactly as sockets reach the system's own.

Verification is not a parameter. A caller given one would eventually use it to make something work,
and the result is a connection encrypted against a stranger rather than private with the intended
server — worse than an unsecured one, because it looks safe. Trust is the machine's own store, so an
internal authority a machine already knows about is believed without this library keeping a list
that would go stale. The name checked is the one the caller named, never one the certificate offers.
## Negative Logic (Prohibited Paths)
- No option to skip verification, accept any certificate, or ignore a name mismatch.
- No trust list of this library's own, which would go stale against the machine's.
- No protocol implementation written here or in Pudu.
## Grill Log
- **Q:** Offer an insecure mode for self-signed certificates in development? **A:** No. _Rationale:_
  the flag outlives the situation that justified it and disables the only property that matters.
  _Rejected:_ a verification argument; a global switch.
- **Q:** Treat a read count as a promise? **A:** No. _Rationale:_ the protocol delivers whole
  records. _Rejected:_ padding short reads.
## Referenced by
[[src/Std/_MOC]] · [[architecture/STDLIB]] · [[Eval Tls]] · [[Std Net]]
