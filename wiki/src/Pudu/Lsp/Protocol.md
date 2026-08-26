---
type: module
path: "@root/src/Pudu/Lsp/Protocol.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.5
depth_status: MEDIUM
tags: [module, medium, tooling, lsp]
aliases: [Lsp Protocol]
---

# Lsp Protocol

## Purpose

Frame messages on the wire and name the shapes they carry.

## Interface

The exported signatures are the module header's export list.

### Governance

- **Everything is bytes.** `Content-Length` counts UTF-8 bytes, and reading that many *characters* would desynchronise the stream the first time a client sent a non-ASCII identifier — after which every later message is read from the wrong offset.
- A request and a notification are separated at the point of decoding rather than checked later, because replying to a notification is the one protocol error a client cannot recover from.
- Only `Content-Length` is acted on. An unknown header is skipped rather than refused, so a newer client can still talk to an older server.
- A client that sends a bare LF instead of CRLF is understood rather than hung up on.
- A `Position` is a zero-based line and a **UTF-16** offset within it, which is what the protocol specifies and what an editor's cursor reports.

### Linkage

- **Requires:** [[Source Text]], [[Diagnostic Model]].
- **Consumed by:** [[Language Server]].

## Algorithm

Direct structural recursion over the shape being read or written; no caching and no mutation.

## Negative Logic (Prohibited Paths)

- No compilation, no analysis, and no decision about what a program means.
- No acceptance of input the format does not admit.

## Referenced by

[[src/Pudu/Lsp/_MOC]] · [[Language Server]] · [[Tooling]]
