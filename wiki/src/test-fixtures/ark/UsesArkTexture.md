---
type: module
path: "@root/test-fixtures/ark/UsesArkTexture.pudu"
fidelity: Active
aliases: [Ark Texture Fixture]
tags: [module, ark, assets, test]
---

# Ark Texture Fixture

## Purpose and interface

Exercise RGBA8 row/channel order, exact texel and center sampling, edge clamping, bilinear midpoint,
sRGB decode-before-filter and linear alpha, premultiplied transparency, one-texel images and
factory selection. Refuse invalid dimensions, byte lengths, fabricated metadata, unknown names,
non-finite UV and out-of-range coordinates. Maximum-Int metadata must return None without index
overflow. Success prints `ark texture: ok` and returns zero.

## Resolved Grill Log

- **Q:** Mirror the filter formula in expected output? **A:** No; use analytic corner/midpoint
  colors and a transparent red beside opaque blue to distinguish incorrect alpha handling.

## Referenced by

[[Ark Texture Asset]] · [[Ark Assets Gate]] · [[src/Ark/_MOC]]
