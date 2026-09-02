---
type: module
path: "@root/src/Pudu/Eval/Tls.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
tags: [module, runtime, network, security]
aliases: [Eval Tls]
---
# Eval Tls
## Purpose
Hold secured connections for one evaluation and move bytes across them.
## Interface
A store created and closed per run, with connect, send, receive, peer name, and close over tokens
the program holds.
## Governance and algorithm
The handshake is performed by a reviewed implementation rather than written here. What this module
owns is the part that must not be defaulted: verification on, the system trust store as the source
of authority, the caller's own name as the name to prove, and a strong cipher selection. The socket
beneath a connection is kept so closing releases both; the protocol's goodbye is sent before the
socket closes, so a far end learns the connection ended rather than inferring it from silence it
cannot distinguish from an attacker cutting the line.
## Negative Logic (Prohibited Paths)
- No parameter, environment variable, or code path that weakens or skips verification.
- No token reuse: a closed connection's token never names a later one.
## Grill Log
- **Q:** Implement the protocol in Pudu, as SHA-256 is? **A:** No. _Rationale:_ a digest is checkable
  against published vectors; a handshake that omits a check produces no wrong answer to check.
  _Rejected:_ a Pudu implementation; an unreviewed one behind a foreign boundary.
## Referenced by
[[src/Pudu/Eval/_MOC]] · [[Std Tls]] · [[Eval Socket]]
