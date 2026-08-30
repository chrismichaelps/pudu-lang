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
Malformed required structure reports `Result`; malformed percent escapes remain literal, and rendering encodes components deterministically without network access.
## Grill Log
- **Q:** Why preserve a malformed escape? **A:** The original text is more honest than an invented replacement scalar. _Rejected:_ lossy guessing.
## Referenced by
[[src/Std/_MOC]] · [[architecture/STDLIB]]
