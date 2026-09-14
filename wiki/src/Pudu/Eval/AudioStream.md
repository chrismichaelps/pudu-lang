---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Eval/AudioStream.hs"
fidelity: Active
tags: [module, runtime, audio, streaming, resource]
aliases: [Eval Audio Stream]
---

# Eval Audio Stream

## Purpose and interface

Own evaluation-local persistent output streams. `AudioStreamStore` maps target-width integer
capabilities to serialized native sessions; open, write, pause, resume, volume, snapshot,
and close operations all revalidate representation bounds and reject stale tokens. Runtime teardown
closes every stream a program leaves open.

An open returns the adapter's actual sample rate and channel count, never merely echoing a request.
A write is bounded by a caller deadline and reports both accepted frames and the native status, so a
partial enqueue can never be mistaken for an all-or-nothing failure. `AudioStreamSnapshot` carries
submitted and hardware-timeline frame positions, underruns, interruptions, device changes, timeline
query failures, state,
and clock nanoseconds derived from the queue timeline. The public Pudu layer converts these
representation values into nominal records and variants.

## Concurrency and ownership

The store lock protects membership only. Each entry has its own lock, so unrelated streams progress
independently while use and close of one pointer are serialized. Close removes ownership exactly
once; stale and double-close operations fail. Teardown first detaches the map and then closes each
entry, preventing new lookup from racing released native memory.

## Grill Log

- **Q:** Expose the native pointer as the Pudu token? **A:** No. _Rationale:_ pointer reuse would let
  a stale value address a later stream and leak platform identity into the language.
- **Q:** Derive playback position from buffer callbacks? **A:** No. _Rationale:_ Apple documents a
  returned buffer as reusable, not necessarily sounded. _Accepted:_ query the audio queue timeline.
- **Q:** Put a process-global stream table in C? **A:** No. _Rationale:_ embedded evaluations need
  isolated teardown and tokens. _Accepted:_ an evaluation-local Haskell registry owns opaque native
  sessions.

Resolved Grill Log: resource identity, operation serialization, and teardown are explicit; callback
state is read only through bounded native snapshots.

## Referenced by

[[Std Audio Device]] · [[Eval Effect]] · [[Eval Runtime]] · [[Pudu Audio Stream Adapter]]
