---
type: module
path: "@root/lib/Ark/Render/Pipeline.pudu"
fidelity: Active
aliases: [Ark Render Pipeline]
tags: [module, ark, render]
---
# Ark Render Pipeline

## Purpose and interface

Vertex processing on lanes. `Light` is a unit direction toward the light, a color and an
ambient floor. `project(mesh, model, viewProjection, light, width, height) -> Option[ScreenBatch]`
multiplies the model-view-projection once, transforms all positions with four lane rows,
divides by w, maps to pixel coordinates with y down, rotates normals by the model's linear part
and renormalizes them, then shades each vertex with clamped Lambert lighting above the ambient
floor. Vertices behind the camera land outside [0, 1] depth and their triangles are skipped by
the device; triangles crossing the near plane are dropped whole until clipping exists.
`concat` joins batches for one draw.

## Grill Log

- **Q:** Shade per pixel? **A:** Not in the software device: per-vertex Gouraud keeps all shading
  in lane kernels. Per-pixel materials arrive with a GPU device.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Render Fixture]]
