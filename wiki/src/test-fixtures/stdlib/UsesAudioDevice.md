---
type: test
path: "@root/test-fixtures/stdlib/UsesAudioDevice.pudu"
fidelity: Active
tags: [test, stdlib, audio, device]
aliases: [Uses Audio Device]
---

# Uses Audio Device

## Purpose and interface

Hold headless one-shot and persistent-plan, empty/malformed PCM, negotiated-format precondition,
volume, close-deadline, large stale-token, and typed-classification assertions for
[[Std Audio Device]]. No valid open request is made, so the suite runs without a speaker.

## Grill Log

- **Q:** Treat this as device evidence? **A:** No. _Rationale:_ it proves only portable admission and
  failure semantics. _Accepted:_ [[Launch Audio Device]] and [[Launch Audio Stream]] are separate
  real-device gates.

## Referenced by

[[Std Audio Device]] · [[Service Evaluation Spec]]
