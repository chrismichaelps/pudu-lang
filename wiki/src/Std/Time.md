---
type: module
path: "@root/lib/Std/Time.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, time]
aliases: [Std Time]
---
# Std Time
## Purpose
Represent instants, durations, dates, and times of day over runtime clock/calendar effects.
## Interface
Exports value types, arithmetic/comparison, formatting/parsing including RFC3339, UTC conversion, local offset, duration description, and elapsed time.
## Governance and algorithm
Calendar and formatting host failures remain `Result`; conversions compose the runtime fields with `?` and preserve millisecond units explicitly.
## Grill Log
- **Q:** Why keep `Instant` and `Duration` distinct when both hold milliseconds? **A:** One is a point and one an amount; mixing them silently would make invalid arithmetic readable. _Rejected:_ one numeric alias.
## Referenced by
[[src/Std/_MOC]] · [[architecture/STDLIB]]
