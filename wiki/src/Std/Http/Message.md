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
`renderRequestBytes` writes a request as the exact bytes sent, head then `Http.requestBytes`, so a
byte body goes out unchanged. `renderRequest` writes text and refuses a request holding a byte body,
as `renderResponse` refuses a byte response, rather than dropping the bytes.
A chunk size arrives from the peer, so hexadecimal digits spelling more than an `Int` holds are not a
size, checked before each multiplication, rather than an overflow that stops the program.
A chunked body's trailer is read field by field under the same header rules, its first field as much
as the rest, and a malformed field refuses the body.

**A header another reader could take differently is refused, not trimmed.** A name is a token —
letters, digits, and ``!#$%&'*+-.^_`|~`` — with nothing between it and its colon. A line beginning
with a space or tab (a folded continuation) and a line still holding a carriage return or line feed
are refused. Each answers `AmbiguousHeader(line)`, in requests and responses alike, and the server
answers 400. The value is still trimmed of surrounding whitespace, which every reader agrees on.

**A request line is three parts one space apart.** A token method, a target holding no whitespace,
and `HTTP/1.0` or `HTTP/1.1`. A doubled, leading or trailing space, a tab, a target holding a space,
a missing version, and a version that never arrives as a line of text are each refused as
`BadRequestLine` rather than split where a guess would put them.
## Grill Log
- **Q:** Trim whitespace before a header's colon, as the parser once did? **A:** No. _Rationale:_ a
  proxy following the protocol rejects `Content-Length : 5` or ignores it, and a server behind it that
  obeys it reads a different body length from the same bytes — the remainder becomes a request only
  the server saw. _Rejected:_ trimming the name; joining folded lines.
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
