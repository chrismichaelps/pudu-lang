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

Exact next action: reproduce with the native pixel test, remove the redundant transform and validate.

## Referenced by

[[handoffs/_MOC]] · [[Pudu Desktop Adapter]] · [[Desktop Presentation Gate]]
