---
type: module
path: "@root/lib/Ark/Render/Clip.pudu"
fidelity: Active
aliases: [Ark Depth Clip]
tags: [module, ark, render]
---

# Ark Depth Clip

## Purpose and interface

`Vertices` holds nine equal-length lanes: homogeneous x/y/z/w, lit linear r/g/b and texture u/v,
three vertices per triangle. `depth(vertices) -> Option[Vertices]` clips triangle polygons against
z ≥ 0 and z ≤ w before perspective division. These are the two depth boundaries for both forward
and reversed zero-to-one depth conventions. Clipping a fully hidden batch returns empty lanes;
an entirely admitted batch returns its original lanes. Triangle order and winding are preserved
through fan triangulation. Any number of `extras` attribute lanes are clipped and interpolated like color. Viewport x/y clipping remains the rasterizer's bounded coverage work.

Malformed lane counts, partial triangles, non-finite inputs and unrepresentable plane distances or intersections
answer None. Retained vertices require positive w. Plane records own distance and boundary-snap
functions in one const table. Sutherland–Hodgman clipping interpolates position, lit color and
texture coordinates in
homogeneous edge parameter; intersection ratios scale distances before division to avoid a
subtraction overflow. Snapping z to zero or w prevents a rounded intersection from escaping its
active depth plane. This is Gouraud color clipping; the render device uses retained w for
perspective-correct interpolation of these lit attributes.
Boundary endpoints are emitted once; a polygon touching a plane only along an edge produces no
triangles. Fully hidden depth batches are rejected before polygon materialization, even when
their signed far distances overflow negatively.

The common fully-admitted path checks lanes and depth bounds without unpacking vertex arrays.
An IEEE zero-product accumulator validates all nine lanes through one final reduction: finite
values contribute zero, while any NaN/infinity poisons its lane. Checked fused lane operations
also enforce matching lengths, avoiding duplicate length and sum passes.
Only batches requiring clipping enter the bounded polygon path; clipping is Pudu engine code,
with existing whole-lane storage operations and no new native renderer API.

## Resolved Grill Log

- **Q:** Clip after dividing by w? **A:** No; homogeneous clipping handles camera crossings and
  preserves interpolation before the division singularity.
- **Q:** Drop a triangle with one outside vertex? **A:** No; clip its polygon and triangulate the
  retained part, preserving winding and authored triangle order.
- **Q:** Permit a tiny negative intersection depth from rounding? **A:** No; snap the active
  plane exactly so the strict raster depth admission does not discard a valid clipped triangle.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Render Pipeline]] · [[Ark Depth Clip Fixture]] · [[Ark Render Correctness]]
