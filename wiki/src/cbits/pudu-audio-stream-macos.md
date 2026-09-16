---
type: module
path: "@root/packages/pudu/v0.1/cbits/pudu_audio_stream.c"
fidelity: Active
tags: [module, runtime, audio, streaming, macos]
aliases: [Pudu Audio Stream Adapter]
---

# Pudu Audio Stream Adapter

## Purpose and algorithm

Implement the private macOS persistent-output boundary with Audio Queue Services. Open allocates two
through eight fixed buffers and one timeline. Writes copy bounded signed-16 PCM into only callbacks'
released buffers and wait on a monotonic deadline; no allocation, lock, interpreter call, or sample
rendering occurs in a callback. Pause, resume, and volume use queue controls. Snapshot reads atomics
plus `AudioQueueGetCurrentTime` and returns one coherent scalar record. Close optionally drains, then
removes listeners, stops, disposes the timeline and queue, and frees the session exactly once.

The output callback marks a buffer reusable and advances acquired frames. Queue property listeners
classify empty running-to-stopped transitions as underruns, nonempty unexpected stops as
interruptions, and current-device changes separately. The first start primes queued buffers. Timeline
sample time—not callback completion—is the media clock exposed for picture synchronization. Raw
queue time is clamped to submitted media: device time advancing through starvation is silence, not
permission for video to outrun content. Each distinct submitted-frame frontier crossed by that
condition increments underrun telemetry once. A temporarily unavailable timeline retains the last
valid monotonic sample and increments an exposed failure counter rather than fabricating progress or
aborting the stream.

## Performance and safety

Every buffer is preallocated. The callback performs bounded atomic operations and a fixed scan of at
most eight buffer addresses. Feed work and platform calls remain on the controlling thread. All
cross-thread fields are C11 atomics, and session destruction occurs only after the evaluator has
serialized use against close.

## Grill Log

- **Q:** Render a Pudu graph in the audio callback? **A:** No. _Rationale:_ interpreter work and
  allocation violate the callback deadline.
- **Q:** Call acquired buffers “played”? **A:** No. _Rationale:_ the platform explicitly makes no
  such guarantee. _Accepted:_ hardware queue timeline for the public clock.
- **Q:** Automatically hide an underrun by restarting? **A:** Restarting on the next write is
  allowed, but the monotonic counter remains visible. _Rationale:_ recovery must not erase evidence.

Resolved Grill Log: callback work, clock meaning, underflow recovery, and destruction order are
bounded and observable.

## Referenced by

[[Pudu Audio Stream Header]] · [[Eval Audio Stream]] · [[Desktop Capability Conformance]]
