---
type: module
path: "@root/test-fixtures/ark/UsesArkAudio.pudu"
fidelity: Active
aliases: [Ark Audio Fixture]
tags: [module, ark, audio, test]
---

# Ark Audio Fixture

## Purpose and interface

Mixes centered voices through a bus (exact samples), pads and releases a finished one-shot,
wraps a looping voice within one block and mutes through the master bus. Positional voices pan
hard right with equal power, attenuate by inverse distance, reach silence with linear rolloff,
multiply gain and occlusion, and change side when the listener turns. Output interleaves to
exact signed 16-bit frames and decodes back to mono. Refusals cover rate, rolloff shape, unknown
buses, negative gain, non-finite positions and samples, bus and listener validation, empty blocks
and occlusion range. Prints `ark audio: ok`.

## Resolved Grill Log

- **Q:** Compare floating output loosely everywhere? **A:** No; centered and bus-scaled samples
  are exact, and only trigonometric pan gains use a tolerance.

## Referenced by

[[Ark Audio]] · [[Ark Audio Gate]] · [[src/Ark/_MOC]]
