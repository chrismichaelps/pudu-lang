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
Malformed required structure reports `Result`; malformed percent escapes remain literal, and rendering encodes components deterministically without network access. A percent escape names one UTF-8 byte: `encodeComponent` writes every byte of the text through a 256-entry module-constant table (an unreserved ASCII byte as itself, any other as `%XX`), and `decodeComponent` gathers bytes, reading `+` as a space, then decodes them once as UTF-8. Decoded bytes that are not UTF-8 return the input unchanged.
## Grill Log
- **Q:** Why preserve a malformed escape? **A:** The original text is more honest than an invented replacement scalar. _Rejected:_ lossy guessing.
## Referenced by
[[src/Std/_MOC]] · [[architecture/STDLIB]]
