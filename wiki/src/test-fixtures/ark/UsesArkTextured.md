---
type: module
path: "@root/test-fixtures/ark/UsesArkTextured.pudu"
fidelity: Active
aliases: [Ark Textured Fixture]
tags: [module, ark, render, assets, test]
---

# Ark Textured Fixture

## Purpose and interface

Checks primitive texture coordinates (plane corners, per-vertex cube coverage, sphere latitude
span, zero defaults, replacement and count refusal, merge). A lit cube projected through
[[Ark Render Pipeline]] and drawn with a 2×2 texture shows each quadrant upright on its front
face with nearest filtering and a blended seam with bilinear filtering; unknown filters, color
spaces and coordinate-lane mismatches answer None while the vertex-color path is unchanged.
A material loaded by [[Ark Asset Server]] from a memory mount (cooked sRGB white albedo, orange
tint) draws through `drawMaterial` as the exact tint. Projected surfaces keep one normal and position per vertex and stay unlit; `drawShaded` gives
the base color under head-on light, shows the sky at full reflectance and refuses invalid
lighting and mismatched surface lanes. Prints `ark textured: ok`.

## Resolved Grill Log

- **Q:** Check textured output only with hand-built screen batches? **A:** No; the fixture goes
  from asset bytes through import, projection and clipping to device pixels.

## Referenced by

[[Ark Render Device]] · [[Ark Render Gate]] · [[src/Ark/_MOC]]
