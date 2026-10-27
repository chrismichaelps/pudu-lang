---
type: module
path: "@root/test/ark-render.mjs"
fidelity: Active
aliases: [Ark Render Gate]
tags: [module, ark, test, render]
---
# Ark Render Gate

Runs [[Ark Render Fixture]]; formats and checks the modules and [[Spinning Cubes Demo]]; renders
the demo offscreen with `--snapshot` and verifies the PPM header, size, background color and
that the scene covers at least a fifth of the frame; requires a positioned type refusal for a
mesh drawn without projection; confirms the modules ship. Registered in
[[Pudu Continuous Verification]].

## Referenced by

[[src/Ark/_MOC]]
