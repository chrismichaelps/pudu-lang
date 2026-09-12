---
type: module
path: "@root/test-fixtures/stdlib/UsesAudio.pudu"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
tags: [module, fixture, stdlib, audio, pcm, wav]
aliases: [Uses Audio]
---

# Uses Audio

## Purpose and interface

Executable Pudu fixture for exact PCM audio. Its `main` returns 42 held assertions.

Resampling and layout: doubling and tripling a ramp's rate interpolates and holds the last sample,
halving keeps every other frame, a same-rate conversion is unchanged, an invalid target rate is
refused, and negative steps round symmetrically; downmixing rounds half away from zero in both
directions, remapping swaps channels, a missing source channel is refused, upmixing refuses a non-mono
source and an invalid channel count, and mono upmixes into every channel.

Formats and buffers: sample rates below 8,000 and channel counts of zero or nine are refused; silence
has exactly the requested frames; a partial frame and a sample outside 16 bits are refused with their
position; sample lookup answers nothing outside frames and channels.

Time: frame counts convert to reduced fractions of a second at 48 kHz and 44.1 kHz, fractions of a
second convert back to frames exactly, a two-hour position lands on its exact frame, and a zero
denominator is refused.

Processing: unity gain returns the same audio; half gain rounds half away from zero symmetrically;
double gain saturates at both 16-bit limits; zero gain silences; gains outside zero to four times unity
are refused; mixing saturates and extends the shorter stream with silence; appending keeps order;
mixing across formats is refused; a slice past the end is padded to exactly the requested frames; and
oversized or negative slices are refused.

WAV: the encoded header's RIFF size, channel count, sample rate, and little-endian extreme samples are
checked byte for byte; decoding the encoding gives the same audio; a truncated document, a document
over the sample budget, a floating-point format, a document without data, and a document without a
RIFF signature are refused with their specific reasons; and an unknown odd-sized chunk before the data
is skipped with its padding byte.

## Grill Log

- **Q:** Round-trip only? **A:** No. _Rationale:_ an encoder and decoder that agree on a wrong layout
  round-trip perfectly. _Rejected:_ round-trip-only WAV checks; header bytes are compared directly.

## Referenced by

[[Std Audio]] · [[Service Evaluation Spec]]
