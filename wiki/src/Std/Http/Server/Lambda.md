---
type: module
path: "@root/lib/Std/Http/Server/Lambda.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, http, serverless, lambda]
aliases: [Std Http Server Lambda]
---
# Std Http Server Lambda

## Purpose

Drive an AWS Lambda-compatible custom runtime directly from Pudu, without a host-language request
adapter.

## Interface

Exports the runtime address and protocol version, invocation and error values, environment discovery,
paths, one-invocation fetch and response operations, startup failure reporting, and the serving loop.
The handler receives undecoded JSON and returns the JSON response body the platform expects.

## Governance and algorithm

The runtime address is a value so fixtures can supply a loopback implementation. The serving loop
long-polls one invocation, preserves its request identifier, posts exactly one response or error for
that identifier, and then asks for the next invocation. Runtime-interface requests permit only the
announced host and retain one 15-minute deadline for the long poll.

The loop depends on [[Std Http Client]] recognizing a complete framed response without waiting for
the peer to close its reusable connection. This is required by Lambda's Runtime API and is ordinary
HTTP/1.1 framing behavior, not a platform exception.

## Grill Log

- **Q:** Add a JavaScript launcher to translate requests? **A:** No. _Rationale:_ Pudu already owns
  JSON, HTTP, routing, and rendering; a launcher would create a second request boundary that can
  disagree. _Rejected:_ Node, shell, or generated host-language request adapters.
- **Q:** Treat socket closure as the end of every Runtime API response? **A:** No. _Rationale:_ the
  interface may retain HTTP/1.1 connections after a complete framed message. _Rejected:_ waiting for
  EOF after `Content-Length` bytes or a complete chunked body.
- **Q:** Reuse an invocation identifier? **A:** No. _Rationale:_ the identifier names the request the
  response settles. _Rejected:_ global or synthesized identifiers.

Resolved Grill Log: the Pudu process is the custom runtime; framed HTTP completion ends each
Runtime API exchange even when the transport remains open.

## Referenced by

[[src/Std/_MOC]] · [[Std Http Client]] · [[Std Http Server]] · [[Pudu Website Architecture]]
