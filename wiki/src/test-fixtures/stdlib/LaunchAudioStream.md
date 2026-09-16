---
type: test
path: "@root/test-fixtures/stdlib/LaunchAudioStream.pudu"
fidelity: Active
tags: [test, stdlib, audio, streaming, hardware]
aliases: [Launch Audio Stream]
---

# Launch Audio Stream

## Purpose and interface

Open a real persistent default-device stream, feed multiple prepared chunks, change volume,
pause/resume, read monotonic queue telemetry and the media clock, drain, and close. The returned
assertion count proves negotiated format, exact submitted frames, nondecreasing timeline values,
state transitions, and stale-token refusal after close.

## Grill Log

- **Q:** Replace this with a mock? **A:** No. _Rationale:_ a mock cannot prove callback reuse,
  hardware timeline access, or queue teardown. _Accepted:_ portable headless validation remains in
  [[Uses Audio Device]], while this explicit acceptance probe uses the real device.

Resolved Grill Log: device success is counted only after real open/feed/control/snapshot/drain/close.

## Referenced by

[[Std Audio Device]] · [[Desktop Capability Conformance]]
