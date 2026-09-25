---
type: module
path: "@root/examples/media/Studio.pudu"
fidelity: Active
tags: [module, example, ui, audio, video, desktop]
aliases: [Media Studio Example]
---

# Media Studio Example

## Purpose and interface

Run one configurable end-to-end Pudu media probe against a real desktop session. `main` loads and
validates an optional nested JSON configuration through [[Media Studio Configuration]], renders the
selected bounded audio graph in fixed-size slices, writes a WAV under the system temporary directory,
feeds that exact PCM to one persistent configured device stream when enabled, uses its negotiated
format and hardware queue timeline as the audio-master media clock, renders moving Canvas pictures, presents
them through one window, pumps close events between frames, and closes the session on every returned
path.

The run measures audio preparation and presentation duration on a monotonic clock and writes a
machine-readable version-three conformance report containing configuration, artifact locations, observed counts,
and honest capability states. Default settings keep the visible smoke run short; the checked
configuration admits larger workloads without allowing unbounded allocation or waits.

The example accepts no foreign capability and declares no platform API. It demonstrates the current
portable public packages while making codecs, native input, display-link pacing, and accessibility
export visible through [[Desktop Capability Conformance]]. The device clock is clamped to submitted
media so hardware time spent starved cannot advance video. Streaming telemetry retains underruns,
interruptions, device changes, and timeline query failures instead of hiding recovery.

## Negative logic

- No raylib, SDL, AppKit declaration, external media process, bundled media asset, or network input.
- No claim that writing a WAV means speaker playback worked; enabled streaming must accept every
  frame, advance its independent queue timeline, and close with an explicit drain.
- No unbounded loop; frame count, audio slice, Canvas allocation, and event wait are bounded.
- No leaked desktop session after an ordinary Pudu error.
- No status is upgraded from `MISSING` or `PARTIAL` merely because the example ran.

## Grill Log

- **Q:** Use `afplay` to make the WAV audible? **A:** No. _Rationale:_ that tests a child process,
  not Pudu's audio device contract. _Accepted:_ [[Std Audio Device]] with a private target adapter.
- **Q:** Decode a downloaded video? **A:** No. _Rationale:_ there is no bounded Pudu codec yet.
  _Accepted:_ generated pictures that exercise exact video timing and the real presenter.
- **Q:** Render enough audio for a long demonstration? **A:** No. _Rationale:_ interpreter sample
  processing is not real-time and graph slices are intentionally capped at 4,096 frames.
  _Accepted:_ configurable total duration assembled from bounded slices, with elapsed time reported.
- **Q:** Call a large preset enterprise-ready? **A:** No. _Rationale:_ production readiness is
  failure recovery, bounds, measurements, and device evidence rather than size. _Accepted:_ one
  checked configuration model and a conformance report that makes missing device APIs visible.

## Referenced by

[[Desktop Capability Conformance]] · [[Examples]]
