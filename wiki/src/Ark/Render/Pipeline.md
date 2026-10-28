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
multiplies the model-view-projection once, batches its first three rows through the existing
3×4 affine lane kernel and computes homogeneous w with one separate row,
divides by w, maps to pixel coordinates with y down, transforms normals by the inverse transpose
of the model's linear part
and renormalizes them, then shades each vertex with clamped Lambert lighting above the ambient
floor. [[Ark Depth Clip]] clips lit homogeneous triangles against both depth planes before
division. Geometry behind the camera is discarded, while crossing triangles retain their visible
polygons. Batches retain clipped w for perspective-correct color interpolation in the device;
already divided depth remains affine in screen space.
Mesh texture coordinates pass through clipping into the batch unchanged by lighting.
`concat` joins batches for one draw.

Non-positive target dimensions and singular/non-finite normal matrices answer None. Ambient light
must be ordered within [0, 1], rejecting NaN. Normal transformation preserves perpendicularity
under non-uniform scale and shear; one fixed matrix inverse is computed per mesh projection,
while vertices remain lane operations.

## Grill Log

- **Q:** Transform normals like positions or tangent directions? **A:** No; use the inverse
  transpose so a normal stays perpendicular to transformed tangents under scale and shear.
- **Q:** Divide by w before camera clipping? **A:** No; clip the homogeneous positions and lit
  colors first, then divide only retained vertices with positive w.
- **Q:** Build each spatial clip row with four temporary lanes? **A:** No; the 3×4 kernel preserves
  written scalar addition order with three output lanes, reducing calls and temporary storage.

- **Q:** Shade per pixel? **A:** Not in the software device: per-vertex Gouraud keeps all shading
  in lane kernels. Per-pixel materials arrive with a GPU device.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Render Fixture]]
