---
type: module
path: "@root/lib/Std/Time/Format/Header.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, time, http]
aliases: [Std Time Format Header]
---
# Std Time Format Header
## Purpose
Own the shape of the three HTTP-date forms and the English month and weekday names that dates are
written with, apart from calendar arithmetic and from the RFC 3339 and pattern codecs.
## Interface
Exports the weekday and month name tables, `MONTH_NUMBERS`, a strict ASCII `digitsAt`, and
`fieldsOf`, which answers year, month, day, hour, minute, and second for the fixed form
`Sun, 06 Nov 1994 08:49:37 GMT` and the obsolete `Sunday, 06-Nov-94 08:49:37 GMT` and
`Sun Nov  6 08:49:37 1994` forms, or the text it refused.
## Governance and algorithm
Each form is recognised by where its first comma sits and read at fixed positions: every literal
piece (`, `, `-`, `:`, ` GMT`) must sit where the form puts it and the text must end where the form
ends. Digits are ASCII only, with no sign and no surrounding space. A two-digit year below 70 is
read in this century. Calendar and clock ranges are left to [[Std Time Format]], which holds the
calendar; this module judges shape only.
## Grill Log
- **Q:** Keep the header reader inside [[Std Time Format]]? **A:** No. _Rationale:_ reading all three
  forms strictly is a grammar of its own, and with it the codec passed the 500-line review gate.
  The name tables move with it because the header grammar is their first reader.
  _Rejected:_ reading only the fixed form, which RFC 9110 section 5.6.7 forbids a recipient to do.
- **Q:** Pivot two-digit years on the current clock, as RFC 9110 suggests? **A:** No. _Rationale:_ a
  reader of text stays pure and repeatable; the fixed epoch pivot answers the same on every run.
  _Rejected:_ reading the clock inside a parser.
## Referenced by
[[src/Std/_MOC]] · [[Std Time Format]]
