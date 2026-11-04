---
type: handoff
status: ACTIVE
aliases: [Ark Texture Delivery]
tags: [handoff, ark, assets]
---

# Ark Texture Delivery

Role transitions: Architect → Engine Asset Engineer → Test Engineer → independent Language
Architect and Forensic Guardian. Own `Ark/Assets/Texture.pudu`, its focused fixture/gate,
nested Cabal shipping entry, test registrations and matching mirrors/navigation. Preserve the
ongoing physics, mesh, render and color work in the shared engine checkout.

The next usable material input is checked CPU RGBA8 data with explicit color space and correct
filtering. Implement clamp-to-edge nearest and bilinear sampling entirely in Pudu. Keep decoding
before linear-light filtering and premultiply during interpolation to avoid transparent fringes.
Resource residency, file import/cook and GPU texture bindings remain separate asset obligations.

The focused assets gate passes sampling, color/alpha boundaries, positioned diagnostics,
formatting and nested source-archive inclusion. Independent API, correctness and Forensic review
approved the implementation without unresolved findings. The preceding color interpolation repair
also passes the focused extended math gate and independent review. No full gates ran locally.

Exact next action: provide virtual resource reads through Ark.Platform for texture asset loading.

## Referenced by

[[handoffs/_MOC]] · [[Ark Texture Asset]] · [[Ark Texture Fixture]] · [[Ark Assets Gate]]
