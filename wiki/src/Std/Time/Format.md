---
type: module
path: "@root/lib/Std/Time/Format.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, time, format]
aliases: [Std Time Format]
---
# Std Time Format
## Purpose
Convert millisecond instants to and from civil parts and protocol/user-facing text.
## Interface
Exports civil-date arithmetic, leap/month queries, RFC 3339 and HTTP-date codecs, pattern-based
render/parse, and duration rendering.
## Governance and algorithm
Civil conversion is arithmetic across the Unix epoch and validates every parsed component.
[[Std Time Format Civil]] owns the calendar arithmetic while this module owns public parts and text
codecs. Formatting is UTC unless an explicit offset is carried; unsupported patterns are typed failures.
`fromRfc3339` requires the fixed separators, a fraction of at least one digit, and an offset of `Z`
or `±HH:MM` (hours below 24, minutes below 60) that ends the text. `fromHttpDate` reads the fixed
form and both obsolete forms through [[Std Time Format Header]] and range-checks the clock.
`dayOfYear` counts from the moment's own year.
## Grill Log
- **Q:** Use a host locale or timezone database implicitly? **A:** No. _Rationale:_ output would vary
  across machines and the distribution carries no zone database. _Rejected:_ table-bound year ranges.
- **Q:** Keep arithmetic and all codecs in one file? **A:** No. _Rationale:_ they form independent
  responsibilities and together exceeded the delivery size boundary. _Rejected:_ a cosmetic split
  that moved only constants.
- **Q:** Let a field reader trim or skip text around the parts it reads? **A:** No. _Rationale:_
  `" 0"`, `junkZ`, and `GMT later` were read as valid moments, so malformed text named a time.
  _Rejected:_ scanning ahead for the zone marker.
- **Q:** Write `dayOfYear` over two lines with the second starting at `-`? **A:** No. _Rationale:_ the
  second line was a new statement, dropping the first line's value; the epoch was the one input
  where the answers agreed. [[Type Check Statement]] now warns with `W3004`.
## Referenced by
[[src/Std/_MOC]] · [[Std Time]] · [[architecture/STDLIB]]
