---
type: module
path: "@root/examples/media/Studio/Config.pudu"
fidelity: Active
tags: [module, example, configuration, media]
aliases: [Media Studio Configuration]
---

# Media Studio Configuration

## Purpose and interface

Own the Media Studio's portable configuration contract. `defaults` supplies a bounded visible smoke
load. `decode` accepts a nested JSON object with required `window`, `audio`, `video`, and `report`
sections. `load` reads an optional file, and `validate` rejects unsafe dimensions, allocation counts,
slice lengths, waits, rates, amplitudes, periods, empty captions, and unsafe artifact names before a
window or media resource is acquired.

The audio section also chooses whether to reach the default device and supplies its frames-per-buffer,
preallocated buffer count, and total playback deadline. These use the same bounds as [[Std Audio
Device]] and are validated before audio generation begins.

The public `Configuration` is made from `Window`, `AudioPlan`, `VideoPlan`, and `ReportPlan` records.
Waveform selection is an exhaustive `Waveform` sum rather than an unchecked string after decoding.
Errors retain the failing field and value where useful, and filesystem/JSON failures remain distinct.

## Negative logic

- Unknown JSON fields are ignored for forward-compatible example configuration; missing or wrongly
  typed required fields are refused.
- Artifact names must be leaf names, so configuration cannot redirect output outside the system
  temporary directory.
- Bounds protect the example process; they are not claims about final device limits.
- Disabling device playback is an explicit headless mode, not successful speaker evidence.

## Grill Log

- **Q:** Use command-line flags for every setting? **A:** No. _Rationale:_ a large flat flag surface
  hides relationships and does not test structured data. _Accepted:_ one optional JSON configuration.
- **Q:** Silently clamp unsafe values? **A:** No. _Rationale:_ that makes the effective workload
  different from the requested one. _Accepted:_ typed, field-specific refusal.
- **Q:** Allow arbitrary output paths? **A:** No. _Rationale:_ an example configuration should not
  overwrite user-selected files. _Accepted:_ checked leaf names under the system temporary directory.

## Referenced by

[[Media Studio Example]] · [[Media Studio Example Configuration]]
