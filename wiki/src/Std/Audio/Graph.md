---
type: module
path: "@root/packages/pudu/v0.1/lib/Std/Audio/Graph.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, audio, graph, render]
aliases: [Std Audio Graph]
---

# Std Audio Graph

## Purpose and interface

A pull-model audio graph over [[Std Audio]]. A `Node` is `Silent`, a `Clip` of audio placed at an
output frame, a `Tone` of a `Wave` (`Square`, `Saw`, `Triangle`) with a period and amplitude, a
`Gained` node, a `Mixed` set of nodes, or a `Ramp` that moves a node's gain linearly between two frames.
`clip`, `tone`, `gained`, `mixed`, and `ramp` build them. `render` produces exactly the requested frames
from a start frame in a format. `GraphError` carries audio refusals unchanged and names invalid periods,
amplitudes, ramps, child counts, nesting beyond the depth bound, and `PositionOutOfRange` for a render
start or clip offset beyond 2⁶¹ frames in either direction.
`KernelFailure` records the invariant breach if a fully admitted bounded request is nevertheless
refused by the compiled byte kernel; it is never mislabeled as malformed caller PCM.

## Governance and algorithm

**A node is a function of frame position.** Tones compute their phase from the absolute frame, clips
place their audio by output frame, and ramps interpolate gain from the absolute frame. No node keeps
state between renders, so a range rendered in one slice or split across many yields the same samples,
seeking is exact, and a presenter chooses its slice size without changing the sound.

**The whole graph is admitted before a sample is produced.** Formats of placed clips, periods of at
least two frames, amplitudes within 16 bits, gains up to four times unity, ramps whose end follows their
start, exactly one child for gain and ramp, and nesting of at most sixty-four levels are checked first,
so an invalid node deep in a mix is refused rather than discovered mid-slice.

**Slices are bounded.** A render requests at most 4,096 frames, the same bound audio slices keep, and
always returns exactly that many frames.

**Exact integer waveforms and automation.** Square is high for the first half of its period, saw rises
from the negative amplitude, and triangle rises over the first half and falls over the second, each by
integer division of exact products. Ramp gain is interpolated per frame by integer division and applied
with the same half-away-from-zero Q15 rounding and saturation as audio gain, so automation is
sample-accurate.

The dense tone-generation and ramp-application loops delegate to [[Eval Audio Kernel]]. Graph
composition, whole-node admission, bounds, and typed errors remain Pudu code; existing exact and
slice-equivalence fixtures hold the compiled byte kernels to the same semantics.

## Referenced archive material

The archived audio unit guides describe a host pulling rendered slices from the end of a processing
chain, each node pulling from its inputs, with a maximum slice size and sample-time stamps that advance
by the frames rendered. This module keeps the pull direction, the bound, and frame-addressed rendering,
and replaces mutable per-unit state with nodes that are functions of frame position.

## Grill Log

- **Q:** Keep oscillator phase as state between renders? **A:** No. _Rationale:_ stateful phase makes
  output depend on slice history, so seeking and slice-size changes alter the sound. _Rejected:_
  stateful nodes; phase comes from the absolute frame.
- **Q:** Validate nodes lazily while rendering? **A:** No. _Rationale:_ failing partway through a slice
  leaves a presenter with a partial buffer. _Rejected:_ lazy validation.
- **Q:** Box single children directly in the variant? **A:** Not in this slice. _Rationale:_ the
  one-element array form is the recursive shape the language admits today; its length is checked.
  _Rejected:_ unchecked child arrays.
- **Q:** Keep exact sample loops interpreted for implementation purity? **A:** No. _Rationale:_ the
  public semantics remain Pudu-native while repeated dynamic dispatch made preparation more than ten
  times slower than playback. _Accepted:_ exact bounded runtime kernels with byte-equality tests.
- **Q:** Reuse a caller-facing audio error if a compiled kernel rejects an admitted request? **A:**
  No. _Rationale:_ that would blame valid PCM for an internal invariant breach. _Accepted:_ the
  explicit `KernelFailure` graph error.
- **Q:** Let an extreme start or clip offset reach checked arithmetic? **A:** No. _Rationale:_ an
  overflow traps the whole program, while a position is caller input that deserves a typed refusal.
  _Accepted:_ a 2⁶¹-frame position bound that keeps every start, offset, and slice sum inside `Int`.

Resolved Grill Log: stateless frame-addressed nodes, whole-graph admission, bounded exact slices, and
integer waveforms and automation.

## Referenced by

Depends on [[Std Audio]].

Consumed by [[Uses Audio Graph]] and [[Service Evaluation Spec]].

[[src/Std/_MOC]] · [[Native Application UI]] · [[2026-09-12-release-readiness-ui]]
