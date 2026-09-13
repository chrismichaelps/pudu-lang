---
type: module-guide
path: "@root/examples/README.md"
fidelity: Active
tags: [examples, guide, testing]
aliases: [Examples]
---

# Examples

## Purpose and interface

Index human-run Pudu programs and distinguish demonstrations from repeatable regression gates.
Examples remain formatter-checked and should compile, but a device-dependent example becomes release
evidence only when its behavior is also represented by deterministic fixtures and a recorded real-device
run.

The media section points to `media/Studio.pudu`, the bounded UI/audio/video integration laboratory.
It names what the run proves and what remains missing so a generated picture or WAV file cannot be
mistaken for complete video or speaker support.

## Negative logic

- Examples do not replace headless semantic fixtures.
- A successful window launch on one operating system does not establish cross-platform support.
- A written media file does not establish device playback, decoding, synchronization, or capture.

## Grill Log

- **Q:** Present Studio as full media support? **A:** No. _Rationale:_ it currently proves the pure
  audio/video models and real picture presentation only. _Accepted:_ link its capability ledger.
- **Q:** Hide device examples because CI may be headless? **A:** No. _Rationale:_ real applications
  must be launched during testing. _Accepted:_ keep manual device probes alongside deterministic CI
  fixtures and record both kinds of evidence.

## Referenced by

[[Module Map]] · [[Media Studio Example]] · [[Desktop Capability Conformance]]
