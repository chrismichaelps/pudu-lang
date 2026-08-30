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
