---
type: module
path: "@root/lib/Ark/Animation/Morph.pudu"
fidelity: Active
aliases: [Ark Morph]
tags: [module, ark, animation, performance]
---
# Ark Morph

## Purpose and interface

Morph targets (blend shapes) on [[Std Lanes]] columns, using [[Ark Limbs]] `Points`. A `Shape`
holds positions and normals. A `Target` is named and moves either every vertex (`dense(name,
delta)`) or only listed vertices (`sparse(name, indices, delta)`, the delta holding one entry per
listed index). `morph(base, targets) -> Result[Morph, MorphError]` validates everything once:
equal column lengths, finite values, sparse indices inside the mesh and not repeated, and unique
target names.

`blend(rig, weights) -> Result[Shape, MorphError]` takes one weight per target in order and
answers base + Σ weight × delta for positions and normals, then renormalizes every normal whose
length is positive and keeps the base normal where the blend cancelled it. A dense target is one
`axpy` per axis; a sparse one scales its deltas and `scatterAdd`s them, so it costs only the
vertices it moves; a zero weight is skipped. `weightsOf(rig, named)` turns a map of target name
to weight into the ordered list, zero for targets it does not name.

`MorphError`: `CountMismatch(what)`, `NonFinite(what)`, `IndexOutOfRange(target, index)`,
`RepeatedIndex(target, index)`, `DuplicateTarget(name)`, `WeightCount(expected, found)`,
`NonFiniteWeight(index)` and `UnknownTarget(name)`.

## Grill Log

- **Q:** Store every target densely? **A:** No; facial shapes move a small region of a large
  mesh, and a dense delta pays for every vertex every frame. Sparse targets pay for what they move.
- **Q:** Accept repeated sparse indices and accumulate them? **A:** No; a repeat is almost
  always an export error, and accumulating it silently doubles a vertex's motion.
- **Q:** Validate on every blend? **A:** No; a morph is built once and blended every frame, so
  checks run at `morph` and a blend only checks its weights.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Animation]] · [[Ark Morph Fixture]] · [[Ark Morph Benchmark]]
