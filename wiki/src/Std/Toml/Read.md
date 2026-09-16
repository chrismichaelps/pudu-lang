---
type: module
path: "@root/lib/Std/Toml/Read.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, toml, configuration]
aliases: [Std Toml Read]
---
# Std Toml Read
## Purpose
Turn configuration text into the value model [[Std Toml]] declares.
## Interface
`read` answers the document or the first reason it is not one. `readValue` reads a single value and
where it ended, for a caller reading a fragment.
## Governance and algorithm
The document is built as it is read rather than gathered and assembled afterwards, because a section
header changes where every later key belongs. A plain header names a table that may already exist
and is not replaced, so keys written under it after another section still land in it; a repeated
header appends a table, and a key written under one belongs to the newest table rather than to the
list. A key given twice is a typed failure rather than a silent last-wins.

Tables under construction are drafts held side by side and named by position. Each keeps its keys
in written order and a map from key to where it points: a value, a nested draft, or the drafts of a
repeated section. Placing a key is one map lookup per segment of its path, and the drafts become
the finished `Toml` once, after the text is read. A key written through a value (`a = 1` then
`a.b = 2`) and a repeated section over a value are refused as `Duplicate` rather than replacing the
value with a table. Inline tables use the same drafts, so a key given twice inside braces is refused
too. Measured at -O2, 5,000 keys in one table read in 0.87 s (43.2 s when every key rebuilt the
tables along its path and searched each sibling), and 5,000 keys across 500 sections in 0.93 s.
## Grill Log
- **Q:** Gather keys first and place them afterwards? **A:** No. _Rationale:_ each key would have to
  carry the header it arrived under, which is the same bookkeeping done less directly. _Rejected:_
  two passes over the document.
- **Q:** Let a repeated section's key attach to the list? **A:** No. _Rationale:_ the format says it
  belongs to the newest table. _Rejected:_ writing over the list.
- **Q:** Keep building the nested `Toml` value directly as each key arrives? **A:** No; build drafts
  addressed by position and finish once. _Rationale:_ an immutable nested value rebuilds every table
  on a key's path, and finding a key among its siblings searched them all, so a table's cost grew
  with the square of its key count. Drafts still place each key as it is read, which is what the
  earlier answer protects. _Rejected:_ gathering keys and assembling in a second pass; a side index
  over the nested value, which must be kept in step with every rebuild.
## Referenced by
[[src/Std/_MOC]] · [[Std Toml]] · [[Std Toml Scan]]
