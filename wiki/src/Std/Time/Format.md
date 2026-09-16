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
## Grill Log
- **Q:** Use a host locale or timezone database implicitly? **A:** No. _Rationale:_ output would vary
  across machines and the distribution carries no zone database. _Rejected:_ table-bound year ranges.
- **Q:** Keep arithmetic and all codecs in one file? **A:** No. _Rationale:_ they form independent
  responsibilities and together exceeded the delivery size boundary. _Rejected:_ a cosmetic split
  that moved only constants.
## Referenced by
[[src/Std/_MOC]] · [[Std Time]] · [[architecture/STDLIB]]
