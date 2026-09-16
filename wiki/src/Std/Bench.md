---
type: module
path: "@root/lib/Std/Bench.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, benchmark]
aliases: [Std Bench]
---
# Std Bench
## Purpose
Measure repeated work and report distribution summaries rather than one stopwatch reading.
## Interface
Exports samples, summaries, comparison/ratio predicates, and stable text rendering.
## Governance and algorithm
Warmup and batched runs amortize clock granularity; min, median, mean, and spread remain visible.
Invalid run/batch counts are normalized to useful minima rather than creating empty statistics.
## Grill Log
- **Q:** Report only elapsed time? **A:** No. _Rationale:_ one reading cannot distinguish a change
  from scheduling noise. _Rejected:_ fabricated universal regression budgets.
## Referenced by
[[src/Std/_MOC]] · [[Performance Constitution]]
