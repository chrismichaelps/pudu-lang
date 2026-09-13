---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Eval/AudioDevice.hs"
fidelity: Active
tags: [module, runtime, audio, device]
aliases: [Eval Audio Device]
---

# Eval Audio Device

## Purpose and interface

Validate the runtime side of one bounded PCM playback request and call the private target adapter.
`playAudioDevice` checks sample rate, channel count, buffer quantum/count, byte alignment, total
frame range, and deadline again at the trust boundary. It maps stable adapter statuses to textual
effect outcomes and returns exact completed frames.

On targets without an adapter it reports the stable unsupported-platform message without allocating
a token or claiming playback.

## Negative logic

- No native pointer or callback crosses into the evaluator value graph.
- No exception or platform status escapes the typed effect result.
- Runtime validation does not trust the standard-library wrapper.

## Grill Log

- **Q:** Add an evaluator resource store for one-shot playback? **A:** No. _Rationale:_ the adapter
  acquires and releases within one call, so a forgeable token would add risk without lifetime value.
  _Accepted:_ add a store with the later persistent streaming-session contract.
- **Q:** Use an unsafe blocking FFI call? **A:** No. _Rationale:_ playback may last seconds and must
  not stop other Haskell capabilities. _Accepted:_ a safe foreign call.
- **Q:** Make the foreign call on the evaluating thread? **A:** No. _Rationale:_ a thread inside a
  foreign call receives no interrupt until the call returns, so Ctrl-C waited out the whole clip and
  a caught `SomeException` then reported it as a platform failure while the program continued.
  _Accepted:_ the call runs on a worker thread; the evaluating thread waits, polls the program's stop
  flag every 5 ms, and on a stop request or an interrupt sets a native cancel token, waits for the
  adapter to release its queue, and answers `cancelled` or re-raises the interrupt. _Rejected:_
  treating any `EINTR` as cancellation, which unrelated signals would trigger.

## Referenced by

[[Std Audio Device]] · [[Pudu Cabal Manifest]] · [[Eval Effect]]
