---
type: module
path: "@root/lib/Std/Toml/Scan.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, toml, lexing]
aliases: [Std Toml Scan]
---
# Std Toml Scan
## Purpose
Read one lexical thing at a time out of configuration text.
## Interface
Skipping blank space and comments, reading a bare or quoted key, reading single-line and multi-line
basic and literal strings, reading one escape, and deciding what an unquoted word means.
## Governance and algorithm
A literal string has no escapes at all, which is what makes it the right way to write a path whose
separator is a backslash. A multi-line string drops a line ending that follows its opening marks.
A whole number is read in the base its marker names with separators removed; anything with a
fractional part or an exponent keeps its source text, so nothing is rounded on the way through. A
date or time is recognised by shape and kept as text, because which of the format's four it is, is a
question [[Std Time Format]] answers.
## Grill Log
- **Q:** Parse moments here? **A:** No. _Rationale:_ the four shapes differ in what they leave
  unsaid, and choosing one would invent a zone or a day. _Rejected:_ converting to a host instant.
- **Q:** Refuse a document over one scalar escape that cannot be represented? **A:** No.
  _Rationale:_ the rest of the file is still readable. _Rejected:_ failing the whole read.
## Referenced by
[[src/Std/_MOC]] · [[Std Toml]] · [[Std Toml Read]]
