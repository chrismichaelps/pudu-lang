---
type: module
path: "@root/test-fixtures/ark/UsesArkAnimation.pudu"
fidelity: Active
aliases: [Ark Animation Fixture]
tags: [module, ark, animation, test]
---

# Ark Animation Fixture

## Purpose and interface

Samples a two-joint, three-key clip at keys, midpoints, clamped and looped (including negative)
times; checks per-joint translation, a unit rotation halfway along its arc, single-key clips,
unknown wraps and NaN times. Blends whole poses, keeps the source at weight zero, layers with
per-joint weights, refuses out-of-range weights and masks, and takes the shorter arc between the
two signs of one rotation. Refuses malformed clips. Drives a state machine through a half-second
cross-fade, an immediate switch, ignored events and every declaration error. Prints
`ark animation: ok`.

## Resolved Grill Log

- **Q:** Check rotations only for unit length? **A:** No; the double-cover case fails if the
  hemisphere correction is removed, which a mutation of the sign lane confirms.

## Referenced by

[[Ark Animation]] · [[Ark Animation Machine]] · [[Ark Animation Gate]] · [[src/Ark/_MOC]]
