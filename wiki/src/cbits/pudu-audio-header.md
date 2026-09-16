---
type: module
path: "@root/packages/pudu/v0.1/cbits/pudu_audio.h"
fidelity: Active
tags: [module, native, audio, abi]
aliases: [Pudu Audio Adapter Header, Pudu Audio Header]
---

# Pudu Audio Adapter Header

## Purpose and interface

Declare the private, framework-neutral ABI for bounded PCM playback. The call accepts signed
little-endian 16-bit interleaved bytes, format, queue quantum/count, and deadline, and writes exact
completed frames. Stable integer outcomes are interpreted only by [[Eval Audio Device]]: success,
invalid argument, deadline exceeded, queue creation, buffer allocation, enqueue, start, release,
drain failure, and cancellation (`0` through `-9`). The caller passes a four-byte cancel token that
`pudu_audio_request_cancel` sets from another thread; the adapter reads it atomically.

## Grill Log

- **Q:** Publish target framework handles in the header? **A:** No. _Rationale:_ this ABI must remain
  implementable by Audio Toolbox, WASAPI, PipeWire/ALSA, or another native target mechanism.

## Referenced by

[[Pudu Audio macOS Adapter]] · [[Eval Audio Device]]
