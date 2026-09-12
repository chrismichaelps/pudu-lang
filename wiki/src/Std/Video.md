---
type: module
path: "@root/packages/pudu/v0.1/lib/Std/Video.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, video, media, timing]
aliases: [Std Video]
---

# Std Video

## Purpose and interface

Exact media timing and ordered picture tracks, written in Pudu with no codec or device binding. `Rate`
is frames per seconds as a reduced fraction; `Timestamp` is ticks at a scale. `rate` and `timestamp`
admit them; `timeOfFrame` and `frameAt` convert between frames and time; `add` and `compare` work on
timestamps at any scales. A `Picture` is a [[Std Ui Canvas]] surface with a presentation time and
duration; `track`, `appended`, and `pictureAt` build and query a `Track`. `audioFrameAt` names the
[[Std Audio]] frame that plays at a video time. `VideoError` names every refusal.

## Governance and algorithm

**Time is exact fractions.** Rates like 30000/1001 are fractions, timestamps are ticks over a scale,
and every conversion, sum, and comparison widens to arbitrary precision before reducing, so frame 107,892
of an NTSC stream begins at exactly 8,999,991/2,500 seconds and maps back to the same frame. Scales and
rate parts are bounded at 10⁹ so reduced results stay in machine integers.

**A track never shows two pictures at once.** Appending requires a positive duration, a presentation
no earlier than the previous picture's end, and the same surface size as the pictures before it.
Because appends keep presentations ordered, `pictureAt` finds the picture on screen by halving and
answers nothing in gaps, before the first picture, and after the last one ends.

**Picture and sound share one clock.** `audioFrameAt` converts a video timestamp with the same exact
arithmetic audio uses, so an audio frame and a picture aligned at the start stay aligned after hours.

## Referenced archive material

The archived media-representation guide describes time as a value over a timescale and time ranges
that exclude their end. This module keeps both—timestamps at a scale and half-open presentation
spans—and adds exact cross-scale comparison and refusal of overlapping pictures.

## Grill Log

- **Q:** Store frame rates as floating point? **A:** No. _Rationale:_ broadcast rates are not binary
  fractions, and error accumulates per frame. _Rejected:_ floating rates and timestamps.
- **Q:** Allow overlapping pictures and pick one? **A:** No. _Rationale:_ an implicit choice hides a
  timing defect in the source. _Rejected:_ last-wins or first-wins overlap.
- **Q:** Decode compressed video now? **A:** Not in this slice. _Rationale:_ codecs must meet the same
  exact, bounded contracts; timing and ordering come first. _Rejected:_ a partial decoder.

Resolved Grill Log: exact fractional time, non-overlapping ordered tracks with same-size pictures, and
audio alignment on one clock.

## Referenced by

Depends on [[Std Audio]], [[Std Ui Canvas]], `Std.Num.Integer`, and [[Std Option]].

Consumed by [[Uses Video]] and [[Service Evaluation Spec]].

[[src/Std/_MOC]] · [[Native Application UI]] · [[2026-09-12-release-readiness-ui]]
