---
type: module
path: "@root/lib/Ark/Math/Camera.pudu"
fidelity: Active
aliases: [Ark Camera]
tags: [module, ark, math]
---
# Ark Camera

## Purpose and interface

Right-handed view space looking down -Z with clip depth in [0, 1]. `lookAt(eye, target, up) ->
Option` (None when eye equals target or up is parallel to the view), `perspective(fovY, aspect,
near, far) -> Option`, `perspectiveReversed(fovY, aspect, near) -> Option` (infinite far plane,
near maps to depth 1, infinity to 0) and `orthographic(left, right, bottom, top, near, far) ->
Option`. Invalid planes, aspect or field of view answer `None`. Clip y points up; a backend whose
framebuffer y points down flips it in its viewport, not in these matrices.

Binary64 throughout with written operation order; degenerate input answers `None`, never NaN.
Depends on [[Ark Math]] and [[Std Math Float]] only, within layer zero.

## Grill Log

- **Q:** Default to reversed depth? **A:** Offer it explicitly: it gives near-uniform precision
  with floating depth buffers, but conventional depth stays available and unambiguous.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Math]] · [[Ark Math Extended Fixture]]
