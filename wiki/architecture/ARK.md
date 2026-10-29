---
type: architecture
status: ACTIVE
aliases: [Ark Engine]
tags: [architecture, ark, performance]
---
# Ark Engine

Ark is Pudu's integrated game-engine library. Engine, gameplay, tools and editor use Pudu;
foreign calls are confined to OS, graphics-driver and audio-device boundaries. Modules ship
under `packages/pudu/v0.1/lib/Ark`, resolved by the existing library root, with no independent
registry package or engine-specific dependency installer. All public APIs remain provisional.
Stable API designation requires extending the current Std-only API lifecycle policy to Ark.
[[ADR-0025-integrated-engine-namespace]] records namespace reservation and migration.

## Dependency contract

Dependencies descend these layers; different roots at one layer stay independent, while submodules
within one root form an acyclic graph. A higher module may
depend on any explicitly named lower module. Submodules inherit their root's layer; low-level
graphics/audio adapters may use Platform, never the reverse. Core and Math do not depend on
each other. Ordinary lower-level Std utilities remain available without importing Ark.

| Layer | Modules | Owned responsibility |
| --- | --- | --- |
| 0 | Ark.Math, Ark.Core | Numeric geometry; containers, serialization, reflection, allocators, tracing |
| 1 | Ark.Platform | Windows, surfaces, action input, clocks, VFS, jobs, dynamic loading, services |
| 2 | Ark.Assets, Ark.World | Import/cook/stream/residency; archetype storage, queries, transforms, prefabs |
| 3 | Ark.Render, Ark.Physics, Ark.Audio, Ark.Net | Render graph and GPU; simulation; mixing; replication |
| 4 | Ark.Animation, Ark.UI | Animation/IK; layout, focus, localization and accessibility |
| 5 | Ark.Game | Lifecycle, levels, cameras, AI, timeline, saves and settings |
| 6 | Ark.Editor, Ark.Tools | Inspectors, content editors, live coding, profiling, plugin boundaries |
| 7 | Ark.Build | Cooking, packaging, cross-target builds, shader variants, performance analysis |

World owns pure simulation storage, never device state. Render extracts a render-world snapshot
from World. Net consumes World changes without a reverse import. Integration among peer systems
is composed by Game. Asset cook algorithms live below their Build orchestration. UI emits drawing
and accessibility commands through Render/Platform; Game composes UI lifecycle. Editor can use
Tools only after an explicit layer refinement, not by creating a same-layer cycle.

## Performance and resource contracts

Math names precision explicitly and preserves IEEE operation order; no implicit fast math or
cross-target deterministic floating-point promise. World will group component columns into bounded
chunks and defer structural mutation until query completion. Generational identifiers must reject
stale access before storage reuse. Job scheduling will declare read/write sets and join owned work.
Persistent Array storage is not evidence of packed mutable storage: the latter needs a measured
language/runtime foundation before claiming ECS throughput.

Assets distinguish identity, dependencies, residency, and owned runtime handles. Reload commits a
validated replacement generation after users of the old one finish. Render records resource reads,
writes and lifetimes before execution; pass culling, aliasing, queue transfers and barriers require
validated hazards. Audio follows the same explicit lifetime rule. Expected failures use Result or
Option, including unavailable device capabilities and invalid external data.

The native execution track is separate from C11 emission. Interpreted conformance fixtures are
useful before it exists, but establish neither native throughput nor a playable renderer. Native
layout, borrowing, FFI buffers/callbacks, allocators, SIMD, jobs and reload code lifetimes require
their own acceptance evidence. Never substitute a host-language engine or broad native middleware.

## Delivery ledger

| Order | Deliverable | Current evidence |
| --- | --- | --- |
| 1 | Math and Core | #652: binary64 Vec3 validated and independently reviewed; other vectors/matrices/quaternions, geometry, noise, containers and Core remain open |
| 2 | Language/native foundations | Existing language features require capability audit; separate native execution target remains open |
| 3 | Platform | OS adapters and bounded deterministic tests remain open |
| 4 | World and simple rendering | Storage/query invariants, native window and a validated GPU frame remain open |
| 5 | Assets, physics, audio and networking | Complete subsystem vertical slices remain open |
| 6 | Animation, UI and Game | Complete subsystem vertical slices remain open |
| 7 | Editor, Tools and Build | Complete subsystem vertical slices remain open |
| 8 | Advanced rendering and game-scale validation | PBR, lighting/shadows/GI, particles, terrain/water/atmosphere, LOD, multi-view/XR and virtualized geometry remain open |

Each row requires success/failure/regression/output checks, measured resource behavior, full-suite
compatibility and independent public API plus vault reviews. A row is not complete because its
namespace or design exists. Physics includes controllers/vehicles and progressive deformables;
Net includes interest, prediction/rollback, dedicated servers and sessions; Audio includes spatial
mixing/streaming/music; Assets includes import through cooked packages; Editor includes typed
inspectors, all content editors and collaboration foundations. These remain target obligations.

[[Ark Swept Motion]] provides callback-driven contact sliding with bounded residual handling;
finite-obstacle query composition is tested separately while its dependency PR remains unmerged.
Floor support and walking/falling/stepping policy remain open.

## Research decisions

The architecture review selected chunked component storage, declared render hazards and explicit
asset residency as techniques to validate through Pudu implementations. No external engine source
has been imported or represented as audited. Primary graphics references are the
[synchronization specification](https://docs.vulkan.org/spec/latest/chapters/synchronization.html)
and [synchronization examples](https://docs.vulkan.org/guide/latest/synchronization_examples.html).
Device synchronization belongs to the application; command submission alone does not establish
resource visibility. Further source/API study remains part of each subsystem's design gate.

## Resolved Grill Log

- **Q:** Separate engine packages? **A:** Namespace modules in the shipped library; share existing
  resolution and release machinery. No package boundary is needed for an import boundary.
- **Q:** Put all integration in World? **A:** No; peer integration belongs to Game to keep imports descending.
- **Q:** Use the C backend as the engine target? **A:** No; native engine execution is a separate prerequisite.
- **Q:** Claim deterministic floats or high throughput from scalar tests? **A:** No; precision is binary64,
  operation order is explicit, and native measurements require an actual native engine target.

## Referenced by

[[architecture/_MOC]] · [[src/Ark/_MOC]] · [[Ark Math]] · [[Ark Foundation Delivery]]
