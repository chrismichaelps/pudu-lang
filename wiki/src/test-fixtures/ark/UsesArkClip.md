---
type: module
path: "@root/test-fixtures/ark/UsesArkClip.pudu"
fidelity: Active
aliases: [Ark Depth Clip Fixture]
tags: [module, ark, render, test]
---

# Ark Depth Clip Fixture

## Purpose and interface

Exercise fully retained/hidden triangles, one/two near-plane vertices outside, far-plane clipping,
exact boundary admission, homogeneous color and texture-coordinate interpolation, winding and
ordered triangle output.
Plane-touching zero-area polygons disappear without duplicate endpoints; large near-plane values
exercise the scaled ratio, and fully hidden extreme far values become empty.
Reject mismatched counts (including texture coordinates), partial triangles, non-finite input
(including texture coordinates) and retained zero w. A camera-crossing
triangle projects and draws visible pixels through the public pipeline. Successful execution prints
`ark depth clip: ok` and returns zero; [[Ark Render Gate]] executes it and includes the module in
its shipping assertion.

## Resolved Grill Log

- **Q:** Test only a polygon count? **A:** No; assert analytic intersection coordinates/colors
  and retained depth bounds, then require visible pixels from the complete engine path.

## Referenced by

[[Ark Depth Clip]] · [[Ark Render Gate]] · [[src/Ark/_MOC]]
