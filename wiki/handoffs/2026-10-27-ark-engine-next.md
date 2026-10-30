---
type: handoff
status: ACTIVE
aliases: [Ark Engine Next]
tags: [handoff, ark]
---
# Ark Engine Next

Continue engine development in feature/660-ark-matrix. Current integrated modules include Math,
Core handles/profiling, World columns/hierarchy/events, Platform input/clock/window/virtual files,
checked CPU texture assets, translating-body physics and software rendering. The layer gate reports
30 engine modules and zero findings. Preserve the preceding session's mesh/demo/benchmark files and
all current implementation work; the engine checkout contains uncommitted continuation slices.

[[Ark Physics Continuation]] records reviewed numeric admission, normalized constraint weights
and disjoint high-degree contact batches. [[Ark Render Correctness]] records inverse-transpose
normals, homogeneous near/far clipping and perspective-correct lit color with affine screen depth.
The focused render gate includes analytic pixels, extreme homogeneous-weight cases, camera-crossing
coverage, source layout/precision checks, offscreen output and shipping. The existing affine raster
entry remains compatible. The optimized executable build passed -Werror; no full gates ran locally.

[[Ark Texture Delivery]] records checked RGBA8 data with explicit sRGB/linear decoding, nearest and
premultiplied bilinear sampling. [[Ark Vfs Delivery]] records real-directory and immutable memory
mounts, typed resource reads and a real resource-to-texture integration check. Focused asset and
Platform gates plus independent API/Forensic reviews pass. Color interpolation now preserves exact
endpoint bits and finite opposite-extreme interior values; the focused extended math gate passes.

The installed runtime resolves to the optimized engine build. A 20-frame FallingBodies run after
correct clipping/interpolation measured 23.7 ms render and 2.37 ms per solver step. The separate
1,000-body benchmark measured 15.1 ms per step with 1,000 mean contacts. Presentation is excluded
from render scopes, and fixed-step counts vary per displayed frame. These are local subsystem
measurements. Packing the three spatial projection rows reduced a consumed-result sphere-projection
microbenchmark from about 260 to 242 microseconds (about 7%); representative full batches remain
byte-identical, and nonsymmetric scalar-matrix assertions protect coefficient layout.

Standing rule: kind discriminators use const factory tables. Keep host resource access in Platform
and preserve descending engine imports. Resource residency, streaming, GPU device support, angular
physics and the remaining full-engine systems retain their target obligations in [[Ark Engine]].

Since then, every spec layer has a validated vertical slice on this branch: perspective (#690),
textured (#697) and PCM (#704) native kernels on stacked PRs; asset graph (#693), asset server with
staged hot reload (#696) and textured/material draws; animation clips, pose blending and a
cross-fading state machine (#702); a spatial lane audio mixer (#706); a scene-stack game loop and
camera rigs (#707); immediate-mode UI with keyboard focus (#708); acknowledged packets and
quantized delta replication (#709); deterministic packs, pack mounts and cook/load (#710). Pudu
fixes found on the way have their own PRs from `dev`: `Bytes.strided` (#701, snapshot 1,056 ms to
1 ms) and position-aware `W3003` (#703). All fifteen focused gates, the layer gate (43 engine
modules, 0 findings), the formatter and API coverage pass on an optimized -Werror build.

Since then: per-pixel shading (#712), a parallel system schedule over declared column access
(#725, stacked PR on this branch), top-row-first native presentation (#724, PR #727), shared
lane collections so lane work overlaps across threads (#726, PR #729, stacked on #669), and
issue #730 for leaks in the bounded `Std.Concurrent` helpers. The window slice (#728:
high-DPI frames, full screen, size limits, focus and minimize records) has its native adapter,
native test and Haskell builtin on feature/728-window-modes, unpushed.

Merged into dev on 2026-10-29 without review, as the user asked: the lanes and raster kernel
stack, the engine integration branch (schedule, window state and settings), the presentation
fix, shared lane collections, the concurrency release fix, the physics and character slices and
`Self` in trait defaults (#745). The full gate passed on the merged dev. Inverse kinematics
(#746) follows on its own branch. A Codex session owns `Std.Binary` (#739, PR #741) and run-time
trait provider dispatch (#742, #743, PR #744); #734 and #735 wait on that work. The Ark archive
(#732) builds on `Std.Binary` once it lands.

Morph targets (#747) stack on the IK branch, and asset streaming (#748) on morph targets.

Open target obligations: lights, shadows and text rendering; Core allocators; editor and
tools.

Exact next action: rebase #732 onto `Std.Binary` once PR #741 merges, keeping only the engine's
versioned save framing in Ark.Core.

## Referenced by

[[handoffs/_MOC]] · [[Ark Engine]] · [[Ark Texture Delivery]] · [[Ark Vfs Delivery]]
