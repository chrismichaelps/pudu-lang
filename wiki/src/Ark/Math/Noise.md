---
type: module
path: "@root/lib/Ark/Math/Noise.pudu"
fidelity: Active
aliases: [Ark Noise]
tags: [module, ark, math]
---
# Ark Noise

## Purpose and interface

Improved gradient noise. `perlin2(x, y)` and `perlin3(x, y, z)` answer values in about [-1, 1];
`fbm3(x, y, z, octaves, lacunarity, gain)` sums octaves. A const permutation table of 512 entries
avoids wrap arithmetic; lattice coordinates come from the exact floor and toInt kernels, and
gradients from the low hash bits. Only exact operations are used, so output is bit-identical.

Binary64 throughout with written operation order; degenerate input answers `None`, never NaN.
Depends on [[Ark Math]] and [[Std Math Float]] only, within layer zero.

## Grill Log

- **Q:** Use a seedable table? **A:** The fixed table keeps noise reproducible; callers vary
  the domain offset per seed instead of rebuilding the table.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Math]] · [[Ark Math Extended Fixture]]
