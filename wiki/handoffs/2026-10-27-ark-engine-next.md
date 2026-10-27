---
type: handoff
status: ACTIVE
aliases: [Ark Engine Next]
tags: [handoff, ark]
---
# Ark Engine Next

Engine branch feature/660-ark-matrix (draft PR #667) now carries Math (#660, #666), lanes
(#668), the nanosecond clock (#670), Core handles/profiling and the archetype World (#672),
adapter game input (#673) and Platform (#675). Layer gate: 17 engine modules, no findings.
Dependency PRs awaiting review: #663, #664 (with #665), #669, #671, #674.

Standing rule: any kind discriminator is built through a const factory table.

Exact next action: a software render device for Ark.Render — a native rasterization kernel
family (cleared color/depth targets, depth-tested triangle fill from transformed lanes) behind a
`RenderDevice` boundary, with frame-graph passes, culling and vertex transforms in Pudu, then a
window demo presenting frames through [[Ark Window]].

## Referenced by

[[handoffs/_MOC]] · [[Ark Engine]]
