---
type: module
path: "@root/test/Pudu/Compiler/Program/Eval/ProtocolSpec.hs"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
tags: [module, test, protocol, evaluation]
aliases: [Protocol Evaluation Spec]
---
# Protocol Evaluation Spec

## Purpose and interface

Runs Pudu fixtures that exercise serialization, HTTP, networking, Lambda invocation, TLS, database
wire formats, and related standard-library protocols. Each fixture returns an exact assertion count;
the Haskell property reports a named counterexample when that count changes.

## Governance and algorithm

The HTTP client fixture includes a loopback peer that sends a complete length-framed response and
keeps the connection open beyond the client's deadline. Success proves message framing, rather than
EOF, ends the response. The Lambda fixture checks request identifiers and response/error paths against
a local Runtime API implementation.

## Grill Log

- **Q:** Accept any positive fixture count? **A:** No. _Rationale:_ a skipped branch could still look
  positive. _Rejected:_ loose lower bounds.
- **Q:** Use the public internet for framing regressions? **A:** No. _Rationale:_ a deterministic
  loopback peer controls both bytes and connection lifetime. _Rejected:_ provider availability in the
  release-blocking suite.

Resolved Grill Log: exact counts make every protocol assertion visible; the persistent-connection
case proves the production Lambda failure cannot regress silently.

## Referenced by

[[UsesHttpClient]] · [[Std Http Client]] · [[Std Http Server Lambda]]
