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
Exports row parsing/rendering, caller-selected delimiters, header tables, named-column lookup,
record projection, and `foldRows`/`foldRowsWith`, which fold a file's rows holding one 64 KiB chunk
and one record at a time and answer `CsvReadError` (`Unreadable(IoError)` or `Malformed(CsvError)`).
## Governance and algorithm
Malformed quotes are typed `CsvError` values and a table refuses row/header width disagreement.

A one-byte delimiter other than a quote or line ending is read by the runtime's `csvRecords`
([[Eval Csv]]), which searches bytes for the next structural character and answers finished rows,
the bytes they span, and the characters they span. `parseWith` hands it the whole text with a final
newline; `foldRows` hands it each chunk joined to the remainder of the last, carries what no newline
completed, and counts characters so an open field reports the position `parse` reports for the whole
text. The interpreted work is one step per row.

The character scanner (`scanWith`) reads any other delimiter and names where an unterminated field
began. It walks the characters once as an array and gathers each field as pieces, so no character is
found by walking the text before it. For such a delimiter `foldRows` gathers lines into records by
quote count, because every quote opens or closes a quoted field or pairs with its neighbour, so a
record is complete exactly when it holds an even number of them.

Measured at -O2 on 20 MB of rows that each hold a quoted field: `parse` takes 0.59 s, where the
character scanner takes 272 s and holds 711 MB; `foldRows` takes 1.53 s at a 99 MB peak; unquoted
rows fold in 0.68 s. Rows before a failure have already reached the step function.
## Grill Log
- **Q:** Split each line and then each separator? **A:** Only after gathering lines into records by
  quote count. _Rationale:_ both may occur inside a quoted field, and an odd count is exactly an open
  field. _Rejected:_ permissively accepting an unclosed quote.
- **Q:** Report a read failure through `CsvError`? **A:** No. _Rationale:_ adding a variant would
  break every exhaustive match on the text parser's errors. _Accepted:_ a separate `CsvReadError`.
## Referenced by
[[src/Std/_MOC]] · [[architecture/STDLIB]]
