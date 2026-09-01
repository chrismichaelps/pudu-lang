---
type: module
path: "@root/lib/Std/Csv.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, csv]
aliases: [Std Csv]
---
# Std Csv
## Purpose
Parse and render separated rows without losing quoted separators, quotes, or embedded newlines.
## Interface
Exports row parsing/rendering, caller-selected delimiters, header tables, named-column lookup, and
record projection.
## Governance and algorithm
The scanner is a single stateful pass over text; malformed quotes are typed `CsvError` values and a
table refuses row/header width disagreement.
## Grill Log
- **Q:** Split each line and then each separator? **A:** No. _Rationale:_ both may occur inside a
  quoted field. _Rejected:_ permissively accepting an unclosed quote.
## Referenced by
[[src/Std/_MOC]] · [[architecture/STDLIB]]
