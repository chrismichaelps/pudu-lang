---
type: test
path: "@root/test-fixtures/stdlib/LaunchAudioDevice.pudu"
fidelity: Active
tags: [test, integration, audio, device]
aliases: [Launch Audio Device]
---

# Launch Audio Device

## Purpose and interface

Generate a short bounded tone in Pudu and present it through [[Std Audio Device]] to the real default
speaker. Success requires the adapter to acknowledge the exact source frame count within the stated
deadline; unsupported or silent no-op behavior cannot pass.

Before the successful tone, submit a one-second silent clip with a one-millisecond deadline and
require `DeadlineExceeded`. The following successful acquisition proves timeout cleanup released the
first queue rather than poisoning the device for the evaluation.

## Grill Log

- **Q:** Run this on headless CI? **A:** No. _Rationale:_ device presence is the behavior under test.
  _Accepted:_ an explicit real-device launch record plus headless admission fixtures.
- **Q:** Infer timeout cleanup from source inspection? **A:** No. _Rationale:_ a queue can appear to
  stop while retaining target resources. _Accepted:_ timeout followed by successful reacquisition.

## Referenced by

[[Std Audio Device]] · [[Desktop Capability Conformance]]
