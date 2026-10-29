---
type: module
path: "@root/lib/Ark/Audio.pudu"
fidelity: Active
aliases: [Ark Audio]
tags: [module, ark, audio]
---

# Ark Audio

## Purpose and interface

A block mixer for game audio. `Sound` holds mono Float64 samples in [-1, 1]; `decode(pcm)` decodes
signed 16-bit [[Std Audio]] PCM (downmixing stereo) through native lane conversion and
`fromSamples` admits finite lanes. `create(rate, rolloff)` starts with a `master` bus at unit gain
and the listener at the origin with +x to its right. `setBus` adds or retunes named buses and
`setListener` moves and turns the ear.

`play(mixer, sound, bus, gain, looping, position)` issues an [[Ark Handle]] for a voice on a known
bus; `update` retunes gain, world position and an occlusion factor in [0, 1] that gameplay derives
from scene queries; `stop` and `playing` use handle liveness. `render(mixer, frames)` mixes every
voice into left/right lanes and advances cursors; looping voices wrap inside a block and one-shot
voices are padded with silence, then released. `toPcm` interleaves and quantizes a block to
device-ready stereo PCM16 with two native lane passes.

Positional voices attenuate through a const factory table of rolloff models (`none`, `inverse`
beyond `near`, `linear` to silence at `far`) and pan with equal power from the listener-relative
direction's projection on the listener's right. Centered voices play at unit gain on both sides.

## Invariants

- Per-sample work is lane kernels: one slice/concat per voice segment and one axpy per channel.
- A voice's level is master × bus × gain × occlusion × attenuation × pan; every factor is finite
  and non-negative by admission.
- Mixing is deterministic: voices are visited in handle-slot order.

## Resolved Grill Log

- **Q:** Mix in 16-bit integers? **A:** No; Float64 lanes keep headroom across buses and quantize
  once at output, where clamping happens.
- **Q:** Linear panning? **A:** No; equal-power panning keeps loudness constant as a source moves
  across the listener.
- **Q:** Model occlusion by ray casting inside the mixer? **A:** No; the mixer stays independent of
  physics. Gameplay supplies an occlusion factor from its own queries.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Audio Fixture]] · [[Ark Audio Gate]]
