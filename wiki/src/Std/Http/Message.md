---
type: module
path: "@root/lib/Std/Http/Message.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, http]
aliases: [Std Http Message]
---
# Std Http Message
## Purpose
Parse and render HTTP request/response text, validate declared body length, and decode chunked bodies.
## Interface
Exports `MessageError`, request/response parsers and renderers, response constructors, framing
completion, `checkLength`, chunk decoding, and `explain`.
## Governance and algorithm
Protocol text accepts CRLF or LF, reports structural failures as `Result`, and never performs transport. Parsing separates head/body, validates lines and headers, then constructs [[Std Http]] values.
Framing completion recognizes a complete declared-length body, terminating chunk stream, bodyless
status, or response to `HEAD` without requiring transport closure.
## Grill Log
- **Q:** Why accept LF? **A:** Hand-written fixtures remain useful without weakening network output, which still renders CRLF. _Rejected:_ transport-dependent parsing.
- **Q:** Is connection closure the only complete-response signal? **A:** No. _Rationale:_ HTTP/1.1
  length and chunk framing are complete while a reusable connection remains open. _Rejected:_ EOF as
  the boundary for every response.
## Referenced by
[[src/Std/_MOC]] · [[Std Http]] · [[Std Http Client]]

## UTF-8 length contract

`respond` writes the UTF-8 byte count in Content-Length. `checkLength` compares the declared
length against the same byte count and reports received bytes in ShortBody. It continues to
accept extra body bytes under its existing minimum-length contract.
Resolved Grill Log: HTTP lengths count octets, never Unicode characters. The server already
uses UTF-8 bytes when adding an absent length; explicit reply headers must use that same unit.


## TLS and binary compression implementation contract

renderResponseBytes serializes headers as UTF-8 and appends Http.responseBytes without decoding. renderResponse remains text-only and refuses binary payloads. respondBytes constructs binary responses with an exact octet Content-Length.

Resolved Grill Log: protocol bytes must remain bytes; verified transport cannot downgrade. Errors remain explicit and resource ownership transfers once. Implementation is code-only; no validation or readiness claim.

## High-performance header parsing contract

`headLines` splits on the detected line separator (`\r\n` or `\n`) directly and trims any trailing empty slice via a single slice bounds check, avoiding $O(N)$ intermediate array pushes. `parseHeaders` scans colon delimiters and extracts name and value via `take` and `drop`, eliminating redundant `length()` traversals across UTF-16 Text slices. `parseHead` parses a head that has already been split from the body without rescanning for `\r\n\r\n`.

Resolved Grill Log: header parsing must minimize heap allocations and avoid redundant Unicode length counting; array rebuilding on every line pays a linear interpreter penalty for every header carried.
