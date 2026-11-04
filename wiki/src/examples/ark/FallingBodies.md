---
type: module
path: "@root/examples/ark/FallingBodies.pudu"
fidelity: Active
aliases: [Falling Bodies Demo]
tags: [module, ark, example, physics]
---

# Falling Bodies Demo

## Purpose and interface

Forty-eight spheres and axis-aligned boxes fall into a walled pit under the translating-body
solver. A const shape-to-mesh table selects cube/sphere geometry. Each frame projects body meshes,
batches one native software draw and presents through the window adapter. Escape quits and R
resets. `--frames n` bounds window execution; `--snapshot path.ppm` simulates 150 steps and exports
an offscreen image. Snapshot export may be slow because pixel-byte conversion is interpreted.

Printed physics means cover individual fixed solver steps; render means cover projection, shading,
batch construction, clear and draw. Window event work and presentation are outside render timing.
The fixed clock may execute multiple physics steps per presented frame, so these means must not
be added as if every frame had exactly one step. Use an optimized compiler for performance work.

## Resolved Grill Log

- **Q:** Derive presented FPS from the render scope? **A:** No; presentation is excluded and the
  fixed-step clock may perform multiple updates. The bounded run is a subsystem measurement.
- **Q:** Assume physics kind names equal mesh kind names? **A:** No; the const vocabulary mapping
  translates box to cube explicitly and refuses an unsupported kind.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Physics Continuation]] · [[Ark Render Pipeline]]
