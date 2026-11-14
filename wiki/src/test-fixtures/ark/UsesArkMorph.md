---
type: module
path: "@root/test-fixtures/ark/UsesArkMorph.pudu"
fidelity: Active
aliases: [Ark Morph Fixture]
tags: [module, ark, test, animation]
---
# Ark Morph Fixture

Checks [[Ark Morph]] on a four-vertex quad with a dense target raising every vertex and a sparse
target moving two vertices and tilting their normals: a mixed blend against hand-computed
positions and renormalized normals, zero weights returning the base exactly, linearity in the
weight, a blend that cancels a normal keeping the base normal, named weights with unnamed targets
at zero, and refusals for mismatched counts, non-finite deltas and weights, out-of-range and
repeated sparse indices, duplicate names, a wrong weight count and an unknown name. Prints
`ark morph: ok`.

## Referenced by

[[Ark Animation Gate]] · [[Ark Morph]]
