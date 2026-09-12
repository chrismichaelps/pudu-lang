---
type: module
path: "@root/test-fixtures/stdlib/UsesAudioGraph.pudu"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
tags: [module, fixture, stdlib, audio, graph]
aliases: [Uses Audio Graph]
---

# Uses Audio Graph

## Purpose and interface

Executable Pudu fixture for the pull-model audio graph. Its `main` returns 21 held assertions.

Rendering: silence of exactly the requested frames at any start; oversized and negative requests
refused; exact square, saw, and triangle samples; a clip before, across, and after its placement; a
linear gain ramp's exact per-frame samples; gain; saturating mixes of gained nodes; and a stereo tone
duplicated across channels.

Slice independence: a triangle rendered as one range equals the same range rendered in two slices, and
a ramp rendered whole equals its two parts.

Refusals: a period below two frames, an amplitude beyond 16 bits, a ramp whose end does not follow its
start, a gain beyond four times unity, a gain node with two children, nesting beyond sixty-four levels,
and a clip whose format differs from the requested one.

## Grill Log

- **Q:** Check slices only individually? **A:** No. _Rationale:_ the graph's central promise is that
  slicing does not change the sound. _Rejected:_ per-slice checks alone; split renders are compared with
  whole ones.

## Referenced by

[[Std Audio Graph]] · [[Service Evaluation Spec]]
