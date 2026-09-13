---
type: test
path: "@root/examples/media/ConfigChecks.pudu"
fidelity: Active
tags: [test, example, configuration, media]
aliases: [Media Studio Configuration Checks]
---

# Media Studio Configuration Checks

## Purpose and interface

Hold deterministic success, malformed-input, unsafe-path, device-queue boundary, and cross-media-duration checks
for [[Media Studio Configuration]]. `main` returns the number of exact assertions held so `pudu test`
can treat the example configuration contract as a repeatable suite without acquiring a device.
The current exact count is eight, including a frames-per-buffer value below the admitted minimum.

## Negative logic

- The fixture does not open a window or write an artifact.
- It does not duplicate audio/video package tests; it covers only configuration-owned obligations.

## Grill Log

- **Q:** Rely on the real Studio run for configuration failures? **A:** No. _Rationale:_ device runs
  are slower and failure cases should not acquire resources. _Accepted:_ a headless sibling suite.

## Referenced by

[[Media Studio Example]] · [[Media Studio Configuration]]
