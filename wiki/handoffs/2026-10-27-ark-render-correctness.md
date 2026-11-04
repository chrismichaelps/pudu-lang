---
type: handoff
status: ACTIVE
aliases: [Ark Render Correctness]
tags: [handoff, ark, render]
---

# Ark Render Correctness

Role transitions: Architect → Engine Library Engineer → Test Engineer → independent Language
Architect and Forensic Guardian. Own `Ark/Render/Pipeline.pudu`, normal-transform assertions in
`UsesArkRender.pudu`, their mirrors and navigation. Preserve the ongoing physics and mesh work.

The vertex pipeline transforms normals with the model's linear matrix, which produces incorrect
lighting under non-uniform scaling or shear. Compute one inverse-transpose normal matrix per
mesh projection; keep every per-vertex operation on lanes. Define explicit None for singular
normal matrices and invalid target dimensions; ordered ambient admission rejects NaN.

The geometric-normal regression failed on the original pipeline and passes with the repair.
Independent API, correctness and Forensic review approved the normal change; focused render
conformance passes. Own the following clipping slice as `Ark/Render/Clip.pudu`, its focused
fixture and render-gate registration, with their mirrors established before implementation.

Depth clipping now passes analytic, camera-crossing, formatter, shipping and layer checks.
Independent API/numerical/Forensic review approved its final finite-validation and boundary
handling with no unresolved findings. The fixed-scene timing probe retains identical depth
checksums with clipping; render scope shows measurable interpreter overhead, not a speedup.

The next role is Render Driver Engineer → Engine Library Engineer → Test Engineer → independent
review. Own perspective support in `Pudu/Runtime/Raster.hs`, its `Pudu/LaneKernel.hs` identity and
`Pudu/Eval/Builtin/Lanes.hs` adapter, `Ark/Render/Device.pudu` and Pipeline batching, plus the
perspective fixture and matching mirrors. This is the engine's software-device boundary, with
no broader compiler work. Keep the original affine raster entry compatible.

Perspective color interpolation now passes analytic pixels, nonconstant affine-depth checks,
tiny/huge/subnormal w invariance, invalid weights, odd-pixel buffers and denominator-underflow
preservation of both targets. The optimized executable build passes -Werror; existing affine
raster output and the focused Ark render gate pass. Independent source/API, test and
Forensic review approved the final changes without unresolved findings. No full gates ran locally.

Material-input preparation exposed a color interpolation defect. Role transitions: Engine Math
Engineer → Test Engineer → independent review. Own `Ark/Math/Color.pudu`, color assertions in
`UsesArkMathExtended.pudu` and their mirrors. The existing fused-difference expression loses
signed-zero endpoints and overflows opposite extreme channels. Preserve endpoints directly and
use weighted opposite-sign interior channels while retaining stable same-sign/extrapolation math.

Exact next action: repair color interpolation and verify the existing focused Ark math gate.

## Referenced by

[[handoffs/_MOC]] · [[Ark Render Pipeline]] · [[Ark Render Fixture]]
