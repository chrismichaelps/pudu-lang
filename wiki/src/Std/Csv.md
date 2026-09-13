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

The pass takes the text's characters once as an array and walks them by index, and each field is
gathered as pieces joined when the field ends; rendering joins fields and lines once. Reading a
character by position from UTF-8 text walks the text before it, and appending to a field copied it,
so the earlier scanner grew with the square of the input: 200,000 characters of quoted rows took
2.55 s at -O2 and now take 0.87 s, four times the 50,000-character time.
## Grill Log
- **Q:** Split each line and then each separator? **A:** No. _Rationale:_ both may occur inside a
  quoted field. _Rejected:_ permissively accepting an unclosed quote.
## Referenced by
[[src/Std/_MOC]] · [[architecture/STDLIB]]
