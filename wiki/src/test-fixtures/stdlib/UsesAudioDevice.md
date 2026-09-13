---
type: test
path: "@root/test-fixtures/stdlib/UsesAudioDevice.pudu"
fidelity: Active
tags: [test, stdlib, audio, device]
aliases: [Uses Audio Device]
---

# Uses Audio Device

## Purpose and interface

Hold headless plan, empty/malformed PCM, boundary, and typed-classification assertions for
[[Std Audio Device]]. No valid playback request is made, so the suite runs without a speaker.

## Grill Log

- **Q:** Treat this as device evidence? **A:** No. _Rationale:_ it proves only portable admission and
  failure semantics. _Accepted:_ [[Launch Audio Device]] is the separate real-device gate.

## Referenced by

[[Std Audio Device]] · [[Service Evaluation Spec]]
