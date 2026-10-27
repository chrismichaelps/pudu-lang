---
type: handoff
status: ACTIVE
aliases: [Ark Engine Next]
tags: [handoff, ark]
---
# Ark Engine Next

Engine branch feature/660-ark-matrix (draft PR #667) now carries Math (#660, #666), lanes
(#668), rasterization (#676), the nanosecond clock (#670), Core and World (#672), adapter game
input (#673), Platform (#675) and Render with the window demo (#680). Layer gate: 21 engine
modules, no findings. Dependency PRs awaiting review: #663, #664, #669, #671, #674, #677, #679.

Standing rule: any kind discriminator is built through a const factory table.

Exact next action: World transform hierarchy and events, then perspective-correct interpolation
and near-plane clipping in the pipeline, then Ark.Physics (rigid bodies on lane columns with a
broadphase over [[Ark Geometry]]).

## Referenced by

[[handoffs/_MOC]] · [[Ark Engine]]
