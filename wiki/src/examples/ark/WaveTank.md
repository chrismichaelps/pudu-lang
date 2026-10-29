---
type: module
path: "@root/examples/ark/WaveTank.pudu"
fidelity: Active
aliases: [Wave Tank Demo]
tags: [module, ark, example, render]
---

# Wave Tank Demo

Water rippling inside a glass tank. A 56×56 height field advances by the damped wave equation
(`next = h + damping (h - previous) + courant (neighbours - 4h)`, courant 0.3 for stability) with
neighbour index tables built once, so every step is four gathers and a few axpy kernels; walls
reflect by repeating the edge point. Each frame gathers the grid into a smooth-shaded triangle
mesh with normals from central differences, tints steep facets toward sky color and draws it with
the tank through [[Ark Render Pipeline]] and [[Ark Render Device]]. Drops fall every 45 steps,
Space splashes the center, Escape quits. `--snapshot <path.ppm>` renders offscreen after 90
steps; `--frames <n>` stops a windowed run. Measured locally at -O2: about 0.3 ms per wave step
and 21 ms per 640×480 frame.

## Resolved Grill Log

- **Q:** Loop over grid cells in Pudu? **A:** No; precomputed neighbour and triangle index tables
  turn the simulation and mesh building into native gathers.
- **Q:** Blend translucent glass? **A:** The device has no blending; the tank shows its back walls
  and posts and leaves the front open to the camera.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Render Gate]]
