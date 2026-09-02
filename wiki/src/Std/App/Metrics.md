---
type: module
path: "@root/lib/Std/App/Metrics.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, application, metrics, observability]
aliases: [Std App Metrics]
---
# Std App Metrics
## Purpose
What a running program reports about itself, as a value, with the failure mode that takes down
monitoring systems made unreachable.
## Interface
A set of measurements. A counter that only rises, a gauge that moves either way, and a distribution
over stated boundaries. Declaring each with the unit it is in. Adding to, setting, and observing
one. Reading a value back. The labels a measurement is broken down by, and the bound on how many
combinations one metric may have. Rendering the set in the text form a collector reads.
## Governance and algorithm
**A set of measurements is a value.** Adding to a counter answers a new set. That is what lets the
whole of this be checked by comparing values, and it is why a program holds its measurements
wherever it holds its other state rather than in something global that every module can reach.

**A metric states its unit when it is declared.** The commonest operational failure with metrics is
not a wrong number, it is a right number in a unit nobody wrote down — a duration that is seconds on
one dashboard and milliseconds on another, discovered during an incident. The unit is part of
declaring the metric and is rendered with it.

**How many label combinations a metric may have is bounded, and the bound is refused rather than
exceeded.** Unbounded labels are the way a monitoring system is taken down: a label carrying a user
identifier, a path with an identifier in it, or an error message turns one metric into millions, and
the collector falls over rather than the program. A metric declares its bound; the combination that
would exceed it is refused and counted, so the program keeps running, the existing series keep their
values, and the fact that something was dropped is itself visible.

**A distribution's boundaries are declared, not derived.** Boundaries chosen from observed data
change when the data changes, and a distribution whose buckets moved cannot be compared against
itself last week. They are stated once and the counts are cumulative, which is what the collectors
that read this format expect.

**Nothing is published automatically.** The rendered text is a value. A program that wants it served
writes a route for it, which is also the only place a decision about who may read it can be made.
## Grill Log
- **Q:** Keep the measurements in something global, since everything reports to one place?
  **A:** No. _Rationale:_ a global is reachable from every module including the ones that should not
  report, cannot be compared in a test, and makes two runs of the same program differ. _Rejected:_ a
  process-wide registry.
- **Q:** Let labels be unbounded, since the program knows what it is doing? **A:** No. _Rationale:_
  the program that adds a user identifier to a label always believes it knows what it is doing, and
  the failure lands on the collector rather than on the program that caused it. _Rejected:_
  unlimited series per metric.
- **Q:** Drop the oldest series when the bound is reached? **A:** No. _Rationale:_ a counter that
  restarts at zero because it was evicted reports a fall that never happened, and a fall in a
  counter is what alerting treats as a restart. Refusing the new one keeps every existing series
  truthful. _Rejected:_ eviction.
- **Q:** Derive histogram boundaries from what has been observed? **A:** No. _Rationale:_ a
  distribution whose buckets moved cannot be compared against itself last week, which is most of what
  a distribution is for. _Rejected:_ adaptive bucketing.
- **Q:** Time an operation by reading the clock here? **A:** No. _Rationale:_ this module would then
  perform an effect and stop being comparable. A caller reads the clock, which is one line at the
  edge of a program rather than a hidden effect in every measurement. _Rejected:_ a timing helper
  that reads the clock.
## Referenced by
[[src/Std/_MOC]] · [[Std App]] · [[Std App Health]] · [[Std Log]] · [[architecture/WEB]]
