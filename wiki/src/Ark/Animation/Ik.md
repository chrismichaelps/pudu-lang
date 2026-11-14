---
type: module
path: "@root/lib/Ark/Animation/Ik.pudu"
fidelity: Active
aliases: [Ark Ik]
tags: [module, ark, animation]
---
# Ark Ik

## Purpose and interface

Inverse kinematics over world-space joint positions. `twoBone(limb, target, pole, softness) ->
Result[Reach, IkError]` solves a `Limb` (root, joint and end positions): the upper length `u` and
lower length `l` come from the limb, `d` is the distance from root to target. The reach `r` is `d`
clamped to between `|u - l|` and `u + l`; with `softness` `s > 0`, a reach past `u + l - s`
approaches full extension as `u + l - s² / (d - (u + l - s) + s)` instead, so the joint never
snaps straight. The joint sits at distance `a = (u² + r² - l²) / 2r` along the target direction and
`h = sqrt(u² - a²)` toward the pole, in the plane through the root, target and `pole`. `Reach`
holds the new joint and end positions, `rootTurn` and `jointTurn` (shortest-arc rotations taking
each bone's old direction onto its new one, to compose onto the bones' world rotations) and
`shortfall`, the distance left between the end and the target (0 when reached).

The bend plane comes from the pole; when the pole lies on the reach line it comes from the current
joint, and when that is also on the line from any axis perpendicular to the reach. A target at the
root keeps the limb's current direction.

`fabrik(joints, target, tolerance, budget) -> Result[ChainSolve, IkError]` solves a chain of two or
more joints with forward-and-backward reaching, keeping every segment's length and the root fixed.
A target beyond the chain's total length straightens the chain toward it in one pass. Otherwise it
iterates until the end is within `tolerance` or `budget` iterations are spent. `ChainSolve` holds
the joints, `iterations`, the remaining `error` and `reached`.

`IkError`: `NonFinite` for any non-finite input, `ZeroLength` for a coincident pair of joints,
`TooFewJoints(count)`, `NegativeSoftness`, `BadTolerance`, `BadBudget(count)`, and `CountMismatch` when
[[Ark Limbs]] receives columns of different lengths.

## Grill Log

- **Q:** Place the joint with the law of cosines through `acos` and `sin`? **A:** No; `acos` near
  1 loses most of its digits exactly where limbs are nearly straight. The projection `a` and
  height `h` are polynomial and a square root, accurate across the whole reach.
- **Q:** Clamp only beyond full reach? **A:** No; a target closer than `|u - l|` has no solution
  either. Both ends clamp, and `shortfall` reports the distance left in both cases.
- **Q:** Hard clamp at full extension? **A:** Only with `softness` 0. A hard clamp makes the knee
  speed spike as the target crosses full reach; the soft band is continuous in value and slope at
  its start. It is rational rather than exponential so the lane solver computes it with one
  divide; both solvers share the curve.
- **Q:** Substitute epsilon defaults for degenerate input? **A:** Not silently: non-finite input
  and zero-length bones are typed refusals. Directions that are merely undetermined (target at the
  root, pole on the line) take a stated rule.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Animation]] · [[Ark Ik Fixture]] · [[Ark Ik Benchmark]]
