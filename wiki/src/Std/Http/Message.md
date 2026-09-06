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
Exports `MessageError`, request/response parsers and renderers, response constructors, `checkLength`, `decodeChunked`, and `explain`.
## Governance and algorithm
Protocol text accepts CRLF or LF, reports structural failures as `Result`, and never performs transport. Parsing separates head/body, validates lines and headers, then constructs [[Std Http]] values.
## Grill Log
- **Q:** Why accept LF? **A:** Hand-written fixtures remain useful without weakening network output, which still renders CRLF. _Rejected:_ transport-dependent parsing.
## Referenced by
[[src/Std/_MOC]] · [[Std Http]]

## UTF-8 length contract

`respond` writes the UTF-8 byte count in Content-Length. `checkLength` compares the declared
length against the same byte count and reports received bytes in ShortBody. It continues to
accept extra body bytes under its existing minimum-length contract.
Resolved Grill Log: HTTP lengths count octets, never Unicode characters. The server already
uses UTF-8 bytes when adding an absent length; explicit reply headers must use that same unit.
