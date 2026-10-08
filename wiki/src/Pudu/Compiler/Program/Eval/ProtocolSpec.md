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

[[Uses Channel Wait]] requires exact zero after checking typed receive outcomes and payload
preservation. Resolved Grill Log: execute the public wrapper through the actual fixture runner.

[[Uses App Reload]] verifies the development middleware's exact responses and production inactivity.

[[Uses App Metrics Concurrent]] proves exact request observations under concurrent load.

[[Uses Resource Disposal]] proves typed disposal outcomes through both evaluators.

## Purpose and interface

Runs Pudu fixtures that exercise serialization, HTTP, networking, Lambda invocation, TLS, database
wire formats, and related standard-library protocols. Each fixture returns an exact assertion count;
the Haskell property reports a named counterexample when that count changes.

## Governance and algorithm

[[Uses Database Transaction Scope]] runs in the full suite with an exact zero result. It proves
transaction callback revocation and exclusive command admission against an explicit client seam.

[[Database Buffered Read Fixture]] runs the shipped session reader through exact transport
fragmentation, frame budget, coalescing and cleanup checks, with a required zero result.

The HTTP client fixture includes a loopback peer that sends a complete length-framed response and
keeps the connection open beyond the client's deadline. Success proves message framing, rather than
EOF, ends the response. The Lambda fixture checks request identifiers and response/error paths against
a local Runtime API implementation.

The YAML compact-sequence regression compares complete nested trees and succeeds only when
all checks run; its entry result is exactly zero. [[Uses Yaml Compact Sequence]] owns the cases.

[[Uses Yaml Quoted]] verifies escaped/doubled quotes, Unicode scalars, mapping/flow delimiters,
and exact typed failures at physical line numbers.

[[Uses Yaml Block]] compares complete scalar/list/mapping trees and checks literal/folded
paragraphs, indentation, physical final newlines, chomping modes and malformed indentation.

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
