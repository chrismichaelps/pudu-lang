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
## Grill Log
- **Q:** Gather keys first and place them afterwards? **A:** No. _Rationale:_ each key would have to
  carry the header it arrived under, which is the same bookkeeping done less directly. _Rejected:_
  two passes over the document.
- **Q:** Let a repeated section's key attach to the list? **A:** No. _Rationale:_ the format says it
  belongs to the newest table. _Rejected:_ writing over the list.
## Referenced by
[[src/Std/_MOC]] · [[Std Toml]] · [[Std Toml Scan]]
