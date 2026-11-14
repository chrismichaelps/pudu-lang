---
type: handoff
status: IN_REVIEW
issue: 670
aliases: [Monotonic Nanosecond Delivery]
tags: [handoff, delivery, runtime]
---
# Monotonic Nanosecond Delivery

Fresh feature/670-monotonic-nanos from development b230a5d6. Role transitions: Runtime Engineer →
Test Engineer → independent Forensic Guardian. Observed: `clock()` answered whole milliseconds,
so a frame or a native kernel measured as zero or one. Added the `clockNanos` effect, admitted
under confinement and refused at compile time, plus `Std.Time.monotonicNanos`.

Evidence: the effects property checks readings never decrease and that a constant reading the
clock reports E7009; a probe confirmed a 20 ms sleep reads at least 20,000,000 ns, with and
without `--confined`. No full gates were run locally, by request.

Exact next action: use `monotonicNanos` for Ark frame pacing and profiling.

## Referenced by

[[handoffs/_MOC]] · [[Std Time]]
