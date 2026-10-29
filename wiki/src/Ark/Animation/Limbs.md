---
type: module
path: "@root/lib/Ark/Animation/Limbs.pudu"
fidelity: Active
aliases: [Ark Limbs]
tags: [module, ark, animation, performance]
---
# Ark Limbs

## Purpose and interface

Two-bone inverse kinematics for many limbs at once, on [[Std Lanes]] columns. `Points` holds `xs`,
`ys` and `zs` lanes; `solve(roots, joints, ends, targets, poles, softness) -> Result[Solved,
IkError]` computes, for every limb at once, exactly what [[Ark Ik]] `twoBone` computes for one:
the same reach clamp and rational soft band, the same joint placement by projection and height,
the same bend-plane fallbacks (pole, then current joint, then the x axis, then y × direction) and
target-at-root rule, and the same shortest-arc turns, including the half-turn for opposite
directions. `Solved` holds the new `joints` and `ends`, `rootTurns` and `jointTurns` as `Turns`
(`xs`, `ys`, `zs`, `ws` quaternion lanes) and `shortfalls`.

Every step is a handful of whole-lane kernels, and branches are masks chosen with
`Lanes.select`, so the work per limb is a few native arithmetic operations however many limbs a
call holds. Refusals are checked once per call: `CountMismatch` when the columns differ in length,
`NonFinite` when any coordinate is not finite, `ZeroLength` when any bone has no length and
`NegativeSoftness`.

## Grill Log

- **Q:** Loop `twoBone` over the limbs? **A:** No; one interpreted solve costs about 220
  microseconds, so fifty limbs would take a frame's budget. Lanes do the same arithmetic for every
  limb per kernel call.
- **Q:** Separate solvers with separate rules? **A:** No; the fixture solves the same limbs both
  ways and requires identical results, so the batch path can never drift from the scalar one.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Ik]] · [[Ark Ik Fixture]] · [[Ark Ik Benchmark]]
