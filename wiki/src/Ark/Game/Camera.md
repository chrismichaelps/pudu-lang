---
type: module
path: "@root/lib/Ark/Game/Camera.pudu"
fidelity: Active
aliases: [Ark Game Camera]
tags: [module, ark, game, camera]
---

# Ark Game Camera

## Purpose and interface

`follow(position, smoothing)` and `track(rig, target, seconds)` move a point toward a target with
a critically damped spring: no overshoot, most of the gap closed within the smoothing time, and a
rational fit of the exponential decay keeps it stable for any step length. `orbit(focus, distance,
yaw, pitch)`, `steer(rig, yawDelta, pitchDelta, zoom)`, `eye` and `view` circle a focus, multiply
the distance by zoom and clamp pitch to ±1.5 radians so [[Ark Camera]]'s look-at keeps a defined
up direction. Non-finite or non-positive parameters answer None.

## Resolved Grill Log

- **Q:** Lerp toward the target by a fixed fraction per frame? **A:** No; that depends on frame
  rate. The damped spring integrates elapsed seconds.
- **Q:** Allow pitch to reach the poles? **A:** No; looking straight down makes the +y up vector
  parallel to the view direction.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Game]] · [[Ark Game Fixture]]
