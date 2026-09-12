---
type: module
path: "@root/packages/pudu/v0.1/lib/Std/Audio.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, audio, pcm, wav, media]
aliases: [Std Audio]
---

# Std Audio

## Purpose and interface

Exact PCM audio written in Pudu with no device binding. `format` admits a sample rate from 8,000 to
384,000 and one to eight channels. `Pcm` holds interleaved signed 16-bit samples as their
little-endian bytes: `silence`, `fromSamples`, `samples`, `frameCount`, and `sampleAt` build and read
them. `seconds` and `framesAt` convert between frame counts and exact fractions of a second. `gain`,
`mix`, `slice`, and `append` transform audio. `encodeWav`, `decodeWav`, and `decodeWavWithin` write and
read canonical 16-bit PCM WAV documents. `AudioError` and `WavProblem` name every refusal.

## Governance and algorithm

**Samples are bytes in their document order.** The buffer is exactly what a WAV data chunk holds,
so encoding is a derived 44-byte header joined to the buffer, decoding validates the chunk structure
and takes one slice, and slicing, appending, and silence are whole-run byte operations. A sample
outside 16 bits cannot be represented, so range is checked once where integers enter.

**Time is frames, converted at the edge.** A position is a frame count; `seconds` reduces it to a
fraction and `framesAt` widens before multiplying, so an hours-long position is exact rather than an
accumulation of rounded binary fractions.

**Arithmetic is fixed-point and saturating.** Gain is Q15 with 32,768 as unity and four times unity as
the ceiling; products round half away from zero, so gain is symmetric around silence, and saturate at
the 16-bit limits instead of wrapping. Mixing sums with the same saturation and treats the shorter
stream as silence after it ends, carrying the longer stream's remaining bytes untouched. Unity and zero
gain touch no samples.

**Per-sample work reads words, not octets.** Gain, mixing, and `samples` read two adjacent samples as
one little-endian 32-bit word through the buffer's native read, and write octets by table lookup
instead of converting each one.

**A render slice returns exactly what was asked.** `slice` always yields the requested number of
frames, padding with silence past the end, and refuses more than 4,096 frames per call so a renderer
prepared for a bounded slice is never asked to allocate beyond it.

**WAV decoding is bounded and specific.** The RIFF size must fit the document; chunks are walked by
their declared sizes inside it, unknown chunks are skipped with their padding byte, the format chunk
must precede the data and agree with itself, only 16-bit integer PCM is accepted, the data must be a
whole number of frames, and the sample count must fit the caller's budget. Each failure has its own
value.

## Measured

At -O2 on the development host, one second of 48 kHz stereo (96,000 samples): building it from an
integer array takes 0.97 s including process startup; encoding WAV adds about 0.02 s and decoding plus
comparison about 0.03 s, against 1.0 s and 2.35 s when samples were an integer array; half gain plus a
mix adds about 3.3 s, against about 1.8 s with integer arrays, because each processed sample now writes
two octets. Sample-by-sample processing is far from real time in the interpreter; the bounded slice is
the contract a native render path will be held to.

## Referenced archive material

The archived Core Audio overview's sample, frame, and packet vocabulary and its interleaved layouts
shape `Format` and `Pcm`. The archived media-representation guide's rational time values shape
`seconds` and `framesAt`. The archived audio unit guides' render slices that must return exactly the
frames requested, their maximum frames per slice, and their rule against allocation on the render
thread shape `slice` and its bound. None of their types or names are carried over.

## Grill Log

- **Q:** Store samples as an integer array? **A:** No. _Rationale:_ it made WAV encoding and decoding
  visit every sample, and those dominate loading and saving. _Rejected:_ `Array[Int]` storage; measured
  above, it is faster only for sample-by-sample processing.
- **Q:** Use floating-point samples? **A:** Not in this slice. _Rationale:_ integer PCM is exact and
  identical on every host, which is what conformance fixtures need. _Rejected:_ tolerance-based
  equality. Revisit with a float path held to integer references.
- **Q:** Wrap on overflow? **A:** No. _Rationale:_ wraparound turns a loud sample into a full-scale
  click of the opposite sign. _Rejected:_ modular arithmetic.
- **Q:** Accept every WAV variant? **A:** No. _Rationale:_ each accepted variant is decoding code that
  must be bounded and tested. _Rejected:_ silent conversion; other formats are refused by tag and
  bit depth.

Resolved Grill Log: byte-backed exact PCM, frame-counted time, saturating fixed-point processing,
bounded slices, and bounded specific WAV decoding.

## Referenced by

Depends on [[Std Buffer]], [[Std Bytes]], `Std.Num.Integer`, and [[Std Option]].

Consumed by [[Uses Audio]] and [[Service Evaluation Spec]].

[[src/Std/_MOC]] · [[Native Application UI]] · [[2026-09-12-release-readiness-ui]]
