---
type: handoff
status: ACTIVE
issue: 696
aliases: [Ark Asset Server Delivery]
tags: [handoff, ark, assets]
---

# Ark Asset Server Delivery

Role transitions: Architect → Engine Asset Engineer → Test Engineer → independent Language
Architect and Forensic Guardian. Begin with owned `Ark/Assets/Graph.pudu`, its fixture, focused
assets-gate registration and mirrors/navigation. Preserve all existing engine continuation work.

The reviewed design separates pure dependency validation/order from importer factories and server
revision state. Graph traversal is iterative and validates missing/duplicate edges before ordering.
The following server slice will use store-local generational handles, immutable snapshots and
dependency-revision bindings. Unchanged source/payload with unchanged dependencies is a no-op.
Changed sources and their transitive dependents stage in dependency-first order; publication occurs
only after all imports succeed. Unload refuses loaded dependents and retains revision history.

Handles do not establish global uniqueness or unforgeable ownership. Atomicity concerns published
server state, not a filesystem-wide source snapshot. Existing directory reads can observe concurrent
source changes. Current importer payloads are bytes and raw RGBA8; derived material importers remain
an explicit next extension rather than an implied capability.

The pure graph (#693) now passes [[Ark Asset Graph Fixture]] through the focused assets gate:
exact diamond order, unique closures, typed declaration failures, cycles with blocked
descendants, forged graph references and a 1,000-node chain.

The server (#696) now passes [[Ark Asset Server Fixture]]: importers run through a const table,
handles are generational, and a real on-disk rewrite reloads a texture and its material in one
staged publication while byte-identical rewrites and failed stages publish nothing.

Exact next action: sample material textures in the render pipeline so imported assets reach
the screen.

## Referenced by

[[handoffs/_MOC]] · [[Ark Asset Dependencies]] · [[Ark Vfs Delivery]] · [[Ark Texture Delivery]]
