---
type: module
path: "@root/packages/pudu/v0.1/cbits/pudu_audio_stream.h"
fidelity: Active
tags: [module, runtime, audio, streaming, native]
aliases: [Pudu Audio Stream Header]
---

# Pudu Audio Stream Header

## Purpose and interface

Declare the private target-adapter ABI for persistent signed-16 interleaved output: opaque session
open, bounded write, pause, resume, volume, telemetry snapshot, and close. Fixed-width integers and a
plain snapshot record are the entire boundary; Apple, pointer, callback, and queue types stay private.

Status and state numbers are closed, stable adapter values translated by [[Eval Audio Stream]]. A
successful open returns the negotiated format. Close accepts an explicit drain policy and deadline.

## Grill Log

- **Q:** Reuse the one-shot function with hidden globals? **A:** No. _Rationale:_ ownership,
  backpressure, and teardown would be unverifiable across evaluations.
- **Q:** Put Pudu records across C ABI? **A:** No. _Rationale:_ the language representation is not a
  stable platform ABI. _Accepted:_ fixed-width scalar carriers.

Resolved Grill Log: opaque ownership and every operation outcome are explicit.

## Referenced by

[[Pudu Audio Stream Adapter]] · [[Eval Audio Stream]] · [[Pudu Cabal Manifest]]
