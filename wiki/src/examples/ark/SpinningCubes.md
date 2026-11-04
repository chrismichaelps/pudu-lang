---
type: module
path: "@root/examples/ark/SpinningCubes.pudu"
fidelity: Active
aliases: [Spinning Cubes Demo]
tags: [module, ark, example]
---
# Spinning Cubes Demo

Twenty-five cubes as [[Ark World]] entities spin under a lane system at a fixed 60 Hz step
([[Ark Frame Clock]]); A/D or arrows orbit the camera and Space pauses through an action map
([[Ark Input]]); Escape or closing the window quits ([[Ark Window]]). Each frame projects every
cube and the ground with [[Ark Render Pipeline]], concatenates them and draws once on
[[Ark Render Device]]. `--snapshot <path.ppm>` renders frame thirty offscreen; `--frames <n>`
stops after n frames and prints the mean render time.

Measured at -O2 on the development machine: one 640×480 frame of the scene renders in about
14–18 ms; a 180-frame window run presented every frame and closed cleanly (#680).

## Referenced by

[[Ark Render Gate]] · [[Ark Engine]]
