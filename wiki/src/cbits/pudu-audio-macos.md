---
type: module
path: "@root/packages/pudu/v0.1/cbits/pudu_audio.c"
fidelity: Active
tags: [module, native, audio, macos]
aliases: [Pudu Audio macOS Adapter, Pudu Audio Adapter]
---

# Pudu Audio macOS Adapter

## Purpose and interface

Implement [[Pudu Audio Adapter Header]] on macOS with public Audio Toolbox queue services. Allocate
every queue buffer before start, copy interleaved PCM into free buffers outside the callback, use a
monotonic clock for the caller's deadline, and stop/dispose on every return path. The callback only
adds completed frame counts and marks one known buffer free with atomics.

A buffer callback means the queue consumed the buffer, not that the device sounded it. After the last
byte is submitted the adapter flushes the queue, requests an asynchronous stop, and succeeds only
once the queue reports it is no longer running, still under the same deadline. A queue that stops
early returns its acknowledged count so the caller reports an incomplete clip; a flush, stop, or
running-state query failure is `PUDU_AUDIO_DRAIN_FAILED`.

## Negative logic

- No codec, file I/O, heap allocation, mutex acquisition, logging, or Pudu evaluation in the callback.
- No framework type enters Haskell or Pudu.
- No polling loop lacks the caller's monotonic deadline.

## Grill Log

- **Q:** Allocate each time the callback asks for data? **A:** No. _Rationale:_ allocation is not
  real-time safe. _Accepted:_ two to eight buffers allocated before playback.
- **Q:** Protect callback state with a mutex? **A:** No. _Rationale:_ priority inversion can miss the
  device deadline. _Accepted:_ bounded C atomics; the controlling thread may sleep between checks.
- **Q:** Stop immediately when the last callback arrives? **A:** No. _Rationale:_ the final buffers
  may still be in the output path, and an immediate stop discards them audibly. _Accepted:_ flush,
  asynchronous stop, and a deadline-bounded wait for the queue's running state to clear.
- **Q:** Let an interrupt cancel a play in progress? **A:** Not in the one-shot contract.
  _Rationale:_ the 60-second deadline bounds how long a pending interrupt waits; cancellation belongs
  to the persistent streaming session. _Rejected:_ treating any `EINTR` as cancellation, which
  unrelated signals would trigger.

## Referenced by

[[Pudu Audio Adapter Header]] · [[Std Audio Device]] · [[Pudu Cabal Manifest]]
