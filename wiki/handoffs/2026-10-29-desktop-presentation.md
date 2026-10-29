---
type: handoff
status: ACTIVE
aliases: [Desktop Presentation Delivery]
tags: [handoff, runtime, desktop]
---
# Desktop Presentation Delivery

Issue #724 starts on fresh feature/724-desktop-presentation from fetched dev. Scope owns the
native desktop adapter, native regression/runner, dedicated CI, local gate registration and matching
vault pages/navigation/changelog. Preserve engine checkouts and all other open work.
Role transition: Architect resolved coordinate ownership and mirrored tests before source;
Runtime Engineer reproduces/fixes the native boundary; Tooling/Release verifies and publishes.
Independent implementation, Language Architect and Forensic Guardian reviews remain pending.
No delegated agents, self-approval or merge.

Current-stage testing at engine d7cda170 passed physics/render gates and bounded scenes, but live
window inspection found vertical reversal relative to offscreen images. Pause/resume/orbit passed.
Artifacts remain under the user's Desktop stage-check folder; the issue records the bug before
further engine implementation. The default native view is unflipped, so its unconditional Y transform
is redundant. Preserve ABI, pixel copying, input and accessibility behavior.

The native pixel test fails on the original transform (pixel (0,0) receives the bottom row's
color) and passes with it removed at normal size, resized bounds, 2x backing scale and an empty
frame. An optimized engine build with the fix showed the wave tank window upright, agreeing with
its offscreen snapshot; the engine maps NDC +y to row zero, so no portable code changed. Pointer
records already convert to top-left coordinates and now agree with what is drawn.

Exact next action: obtain independent implementation, Language Architect and Forensic Guardian
reviews on the draft PR.

## Referenced by

[[handoffs/_MOC]] · [[Pudu Desktop Adapter]] · [[Desktop Presentation Gate]]
