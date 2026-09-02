---
type: module
path: "@root/lib/Std/Time/Format/Civil.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, time, calendar]
aliases: [Std Time Format Civil]
---
# Std Time Format Civil
## Purpose
Own proleptic Gregorian arithmetic independently of text parsing and rendering.
## Interface
Exports floor division/modulo, leap and month-length queries, and conversion between civil dates
and Unix-epoch day numbers.
## Governance and algorithm
Negative epochs use floor rather than truncating division. Civil conversion counts complete
400-year Gregorian cycles and has no host locale, timezone, or year table.
## Grill Log
- **Q:** Keep calendar arithmetic inside the text codec? **A:** No. _Rationale:_ arithmetic and
  grammar change for different reasons, and the combined module exceeded the 500-line review gate.
  _Rejected:_ host calendar conversion with platform-dependent ranges.
## Referenced by
[[src/Std/_MOC]] · [[Std Time Format]]
