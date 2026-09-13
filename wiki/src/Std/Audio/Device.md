---
type: module
path: "@root/packages/pudu/v0.1/lib/Std/Audio/Device.pudu"
fidelity: Active
tags: [module, stdlib, audio, device, playback]
aliases: [Std Audio Device]
---

# Std Audio Device

## Purpose and interface

Present one bounded [[Std Audio]] PCM clip to the default output device. `plan` admits a hardware
queue quantum, two to eight preallocated buffers, and a finite monotonic deadline. `play` validates
the PCM representation, refuses an empty clip, invokes the language-owned device effect, and returns
`Playback` with the exact frames acknowledged by the target adapter.

`DeviceError` distinguishes plan mistakes, malformed or empty PCM, unsupported targets, deadline
expiry, cancellation, and platform failure. A program that watches for a stop request and receives
one during a play gets `Cancelled` within a few milliseconds; an interrupt the program does not
handle stops the program as it would anywhere else, after the queue is released. No operating-system type, callback, pointer, or status code enters the
public Pudu API.

## Performance and ownership

The full clip is already byte-backed PCM. The target adapter copies bounded chunks into preallocated
device buffers and refills them outside the audio callback. The callback performs bounded atomic
bookkeeping only. Playback has one acquisition scope and releases every native queue/buffer before
returning, including on start, enqueue, timeout, and disposal failures.

## Negative logic

- Clip playback is not a streaming graph, mixer, codec, capture API, or shared A/V clock.
- A successful unsupported-target no-op is forbidden.
- The deadline is not silently extended, and a partial play is never reported as complete.

## Grill Log

- **Q:** Evaluate `Std.Audio.Graph` from the device callback? **A:** No. _Rationale:_ measured
  interpreter throughput misses the real-time deadline by orders of magnitude. _Accepted:_ prepare
  exact PCM first; add a compiled native-word graph kernel before callback rendering.
- **Q:** Expose Audio Queue or Audio Unit concepts? **A:** No. _Rationale:_ they are one target's
  mechanism. _Accepted:_ quantum, capacity, deadline, and exact completion are portable obligations.
- **Q:** Begin with a persistent streaming session? **A:** Not in this slice. _Rationale:_ device
  switching, interruption, underrun, and clock semantics must be designed together. _Accepted:_ one
  bounded acquisition whose cleanup can be proven now; streaming remains explicitly partial.
- **Q:** Let a play hold a stop request or an interrupt until the clip or deadline ends? **A:** No.
  _Rationale:_ a clip may be up to a minute long, a supervisor's grace period is shorter, and an
  interrupt reported as a platform failure let the program continue. _Accepted:_ `Cancelled` for a
  watched stop request and a re-raised interrupt, both after the queue is released.

## Referenced by

[[Native Application UI]] · [[Eval Audio Device]] · [[Uses Audio Device]] · [[Launch Audio Device]]
