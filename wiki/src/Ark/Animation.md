---
type: module
path: "@root/lib/Ark/Animation.pudu"
fidelity: Active
aliases: [Ark Animation]
tags: [module, ark, animation]
---

# Ark Animation

## Purpose and interface

`Clip` holds key times and key-major joint poses in [[Ark Hierarchy]] `Poses` lanes: key k owns
joints [k · joints, (k + 1) · joints) of every lane. `fromKeys(joints, times, keys)` admits only
positive joint counts, finite strictly increasing times starting at zero, lanes of exactly
`times · joints` finite values and unit rotations (within 1e-6 in squared length).

`sample(clip, time, wrap)` wraps the time through a const factory table (`clamp`, `loop`; loop
wraps negative times too), bisects the key times and blends the two bracketing key blocks.
`blend(from, to, weight)` and `blendMasked(from, to, weights)` interpolate every joint at once:
translation and scale linearly, rotation along the shorter arc (the target is negated per joint
where the dot product is negative) and renormalized. A per-joint weight of zero keeps the source
joint, which layers an upper-body pose over a full-body one. `duration` is the last key time.

## Invariants

- Every per-joint operation is a lane kernel over all joints; only the key search is scalar.
- Keys and interior key times are reproduced exactly; weights outside [0, 1] and NaN answer None.
- Output poses are hierarchy-slot ordered and feed `Hierarchy.setLocals` directly.

## Resolved Grill Log

- **Q:** Store a track per joint? **A:** No; key-major lanes make a key's whole skeleton one
  contiguous slice, so sampling is ten slices and one blend regardless of joint count.
- **Q:** Slerp each joint? **A:** No; normalized linear interpolation on the shorter arc is a lane
  kernel and is monotonic for the small arcs between adjacent keys.
- **Q:** Select wrap modes with a match? **A:** No; a const factory table maps names to wrap
  functions and makes an unknown mode an explicit None.

## Referenced by

[[Ark Ik]] · [[Ark Limbs]] · [[Ark Morph]] · [[src/Ark/_MOC]] · [[Ark Animation Machine]] · [[Ark Animation Fixture]] · [[Ark Animation Gate]]
