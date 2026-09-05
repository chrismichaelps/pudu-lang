---
type: module
path: "@root/lib/Std/Db/Row.pudu"
fidelity: Active
tags: [module, stdlib, database, mapping]
aliases: [Std Db Row]
---
# Std Db Row

## Purpose
Read backend-neutral query results into application values without treating malformed rows,
missing columns, SQL NULL, or wrong storage kinds as interchangeable.

## Interface and algorithm
`value` locates a uniquely named column and validates the requested row's width. Duplicate column
names are ambiguous, not first-match wins; callers can alias columns or use `at` by index.
`nullable` distinguishes SQL NULL from a missing column. Typed readers require the matching
Driver.Value variant, with no implicit numeric narrowing, parsing, or text conversion.
`map` applies a caller-provided mapper in row order, stopping at its first typed failure.
`one` and `optional` enforce result cardinality before invoking their mapper.

## Resolved Grill Log
- **Q:** Read a missing column as NULL? **A:** No; absence of a column is a structural failure.
- **Q:** Choose the first duplicate column? **A:** No; ambiguous names need SQL aliases or explicit indices.
- **Q:** Guess native types from text? **A:** No; PostgreSQL wire text and SQLite native cells retain their actual variants. Application parsers make conversions explicit.
- **Q:** Expose the bad cell in diagnostics? **A:** No; errors carry positions, column names and expected kinds, never database values.

## Referenced by
[[src/Std/_MOC]] · [[Std Db Driver]] · [[Std App Database]] · [[architecture/STDLIB]]
