---
type: module
path: "@root/test-fixtures/stdlib/UsesVideo.pudu"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
tags: [module, fixture, stdlib, video]
aliases: [Uses Video]
---

# Uses Video

## Purpose and interface

Executable Pudu fixture for exact video timing and tracks. Its `main` returns 20 held assertions.

Timing: zero rates, negative ticks, and zero scales are refused; rates reduce; NTSC frame 30 begins at
1001/1000 seconds; the frame shown one second in is 29, at 1001/1000 it is 30, and an hour in it is
107,892, whose start time is exactly 8,999,991/2,500 and maps back to the same frame; negative frames are
refused; sums reduce across scales; comparisons are exact across scales; and 48 kHz audio frames align
with NTSC and 30 frames-per-second times.

Tracks: an empty track shows nothing; pictures are found inside their spans, at their exact starts, and
not in gaps or after the last end; an overlapping picture, a zero-duration picture, a picture of another
size, and an invalid timestamp are refused; and a picture beginning exactly where the previous one ends
is accepted.

## Referenced by

[[Std Video]] · [[Service Evaluation Spec]]
