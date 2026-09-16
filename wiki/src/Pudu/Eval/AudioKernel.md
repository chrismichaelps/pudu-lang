---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Eval/AudioKernel.hs"
fidelity: Active
tags: [module, runtime, audio, performance]
aliases: [Eval Audio Kernel]
---

# Eval Audio Kernel

## Purpose and interface

Generate one bounded exact integer waveform slice and apply one bounded Q15 automation ramp in the
compiled runtime. Both operations consume and return little-endian signed-16 interleaved bytes, and
answer `Nothing` for any malformed representation or bound.

The formulas are the normative [[Std Audio Graph]] formulas: absolute-frame phase, truncating integer
division, half-away-from-zero Q15 rounding, and signed-16 saturation. A 4,096-frame, eight-channel
slice is the largest call, so allocation is bounded before generation begins.

## Negative logic

- No device, clock, callback, floating-point sample, target framework, or mutable graph state.
- No semantic shortcut: existing exact graph fixtures compare the compiled path byte for byte.
- No unbounded request and no partial result.

## Grill Log

- **Q:** Keep per-sample interpreter dispatch on the device preparation path? **A:** No. _Rationale:_
  the measured Media Studio workload took 13.4 seconds to prepare one second of audio. _Accepted:_
  closed, exact byte kernels beneath the Pudu graph API.
- **Q:** Move the public graph into Haskell? **A:** No. _Rationale:_ Pudu retains node composition,
  admission, and typed errors. _Accepted:_ only the two dense arithmetic loops are primitives.

## Referenced by

[[Std Audio Graph]] · [[Eval Builtin]] · [[Pudu Cabal Manifest]]
