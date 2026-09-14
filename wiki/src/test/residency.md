---
type: module
path: "@root/test/residency.py"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
tags: [module, test, release, streaming, memory]
aliases: [Streaming Residency Gate]
---

# Streaming Residency Gate

## Purpose and interface

Given the path to a freshly built `pudu` executable, prove that the file-streaming readers hold as
much memory at ten times the input as at one. It writes a 2 MB and a 20 MB line file, runs
`Std.Io.foldLines` and `Std.Io.countBytes` over each in a separate process, and compares their peak
resident memory. Buffered `Std.Io.readAllLinesOf` runs the same way as a control. Success prints each
reader's two peaks in megabytes as one JSON object.

## Governance and algorithm

A process cannot observe its own peak, so each probe runs as the single child of a small wrapper
whose `getrusage(RUSAGE_CHILDREN)` peak is therefore that program's alone; macOS reports bytes and
Linux kilobytes. Each probe's count must equal the lines or bytes written. A streaming reader may
reach at most 1.25 times its small-input peak plus 8 MB. The buffered control's peak must rise by at
least the extra input it was given: if it does not, the measurement is not seeing memory and a flat
streaming result would prove nothing. The rise is compared with the input rather than as a ratio of
peaks, because most of a small peak is the runtime itself and lines that share their decoded block
are held compactly. The temporary files and probes are removed on every outcome.

Measured through the same peak at 10 MB and 100 MB: `foldLines` 87 → 88 MB, `countBytes` 82 → 82 MB,
buffered `readAllLinesOf` 104 → 359 MB. At the gate's 2 MB and 20 MB the whole run takes about 6 s.

## Grill Log

- **Q:** Accept a flat streaming peak on its own? **A:** No. _Rationale:_ a probe that failed to
  compile, or a measurement of the wrong process, is also flat. _Accepted:_ exact counts plus a
  buffered control that must grow. _Rejected:_ asserting only that streaming stays low.
- **Q:** Measure with `/usr/bin/time`? **A:** No. _Rationale:_ its flags and report differ between
  macOS and Linux, and CI runs Linux. _Accepted:_ `getrusage` from a one-child wrapper, with the unit
  chosen by platform.
- **Q:** Count a buffered convenience reader as streaming evidence? **A:** No. _Rationale:_ it holds
  every line by contract; it is the control, never the claim.

Resolved Grill Log: streaming residency is a measured property of the real binary, checked on every
gate run with a control that proves the measurement works.

## Referenced by

[[Repository Gates]] · [[First Release Readiness]] · [[Std Io]]
