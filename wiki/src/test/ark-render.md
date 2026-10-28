---
type: module
path: "@root/test/ark-render.mjs"
fidelity: Active
aliases: [Ark Render Gate]
tags: [module, ark, test, render]
---
# Ark Render Gate

Runs [[Ark Render Fixture]] and [[Ark Depth Clip Fixture]] with exact output; formats the modules,
fixtures and [[Spinning Cubes Demo]]; renders the demo offscreen with `--snapshot` and verifies the PPM header, size, background color and
that the scene covers at least a fifth of the frame; requires a positioned type refusal for a
mesh drawn without projection; confirms the modules, including [[Ark Depth Clip]], ship. Registered in
[[Pudu Continuous Verification]].

[[Ark Perspective Fixture]] executes with exact output and formatting checks, exercising the
perspective render-driver entry through public device calls. The existing affine raster fixture
remains a compatibility check at the lower driver boundary.

## Referenced by

[[src/Ark/_MOC]]

## Resolved Grill Log

- **Q:** Replace output verification with type checks? **A:** No; analytic pixels, camera-crossing
  coverage, offscreen snapshots and actual archive contents remain focused behavioral evidence.
