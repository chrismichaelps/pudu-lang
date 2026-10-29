---
type: module
path: "@root/src/Pudu/Runtime/Shade.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, performance, render]
aliases: [Runtime Shade]
---

# Runtime Shade

## Purpose and interface

Per-pixel lighting for [[Runtime Raster]]'s shaded entry. `lighting(lane)` reads 20 uniforms —
camera position, direction toward the light (normalized here), light color, ambient floor,
specular exponent and strength, Fresnel reflectance at normal incidence, sky horizon and zenith
colors and the cosine of the sun's angular radius — and refuses non-finite values, a zero light
direction, ambient or f0 outside [0, 1], a non-positive exponent and a sun cosine outside (0, 1).

`shade` takes an interpolated normal, world position and base color. The normal is turned toward
the camera so thin surfaces light from both sides. Color is base × (ambient + (1 − ambient) ·
max(0, n·l)) × (1 − F) + sky(reflect(v, n)) × F + light × strength · max(0, n·h)^exponent, with
Schlick's F = f0 + (1 − f0)(1 − n·v)⁵. The sky blends horizon to zenith by the square root of the
reflected ray's height and adds the light color inside a soft sun disc.

## Grill Log

- **Q:** Light per vertex as the pipeline does? **A:** Not for this entry; highlights and
  reflections are narrower than a triangle, so they are evaluated per pixel from interpolated
  normals and positions.
- **Q:** Pass every uniform as its own kernel argument? **A:** No; one 20-value lane keeps the
  kernel signature stable as material parameters grow.

## Referenced by

[[Runtime Raster]] · [[Raster Fixture]]
