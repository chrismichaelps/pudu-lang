---
type: module
path: "@root/lib/Std/Url.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, url]
aliases: [Std Url]
---
# Std Url
## Purpose
Parse, render, query, and transform URL components as pure data.
## Interface
Exports `Url`, `UrlError`, parsing/rendering, query/path operations, effective/default ports, and component/query encoding and decoding.
## Governance and algorithm
Malformed required structure reports `Result`; malformed percent escapes remain literal, and rendering encodes components deterministically without network access. A percent escape names one UTF-8 byte: `encodeComponent` writes every byte of the text through a 256-entry module-constant table (an unreserved ASCII byte as itself, any other as `%XX`), and `decodeComponent` gathers bytes, reading `+` as a space, then decodes them once as UTF-8. `parse` reads the path and the fragment with the same escapes but keeps `+`, which is a space only in a form-encoded query. Decoded bytes that are not UTF-8 return the input unchanged.
User information before the authority's last `@` is not part of the host and is not kept, so credentials never travel in a field named for the host. A host written in brackets is an IPv6 address: it keeps its brackets, and the port is only what follows the closing bracket. Text with neither `%` nor `+` is returned by `decodeComponent` unchanged, and where the authority and the path end is found with one native search per delimiter.
## Grill Log
- **Q:** Why preserve a malformed escape? **A:** The original text is more honest than an invented replacement scalar. _Rejected:_ lossy guessing.
- **Q:** Accept any count as a port and let the connection fail? **A:** No. _Rationale:_ the error
  then names the network rather than the URL that was wrong. _Rejected:_ wrapping to 16 bits.
- **Q:** Decode a URL's path with `decodeComponent`? **A:** No. _Rationale:_ it reads `+` as a space,
  so `/lang/c++` answered the segment `c  `. A plus means a space only in a form-encoded query;
  `decodeComponent` keeps that documented reading for query text. _Rejected:_ changing
  `decodeComponent` itself, which callers use for form fields.
- **Q:** Export a path-segment decoder? **A:** Yes, `decodeSegment`. _Rationale:_ [[Std Http Server Route]]
  needs a decoder that keeps `+`, and `decodeComponent` keeps its documented form reading.
## Referenced by
[[src/Std/_MOC]] · [[architecture/STDLIB]]
