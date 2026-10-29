---
type: module
path: "@root/lib/Ark/World/Hierarchy.pudu"
fidelity: Active
aliases: [Ark Hierarchy]
tags: [module, ark, world]
---
# Ark Hierarchy

## Purpose and interface

Parent–child transforms for [[Ark World]] entities. Each node has a slot holding its entity
handle, parent slot (−1 for a root) and depth; local and world poses are ten lanes each
(translation, rotation quaternion, scale) indexed by slot. `empty`, `add(h, entity, parent,
local) -> Option` (parent must already be a node), `setLocal`, `setLocals(h, poses)` (replace all
local lanes at once, for animation), `reparent -> Option` (refuses making a node its own
descendant), `remove -> Option[(Hierarchy, Array[Handle])]` (removes the subtree, compacting
every lane with one gather), `propagate`, `world -> Option[Transform]`, `worldPoses`,
`parentOf`, `childrenOf`, `depthOf`, `size`.

`propagate` groups slots by depth. Roots copy their local pose; each deeper level gathers its
locals and its parents' world poses, composes them with lane kernels (scale product, rotated
and scaled translation, Hamilton product) and scatters the results: a few dozen native passes
per level, independent of node count. Composition is exact under uniform parent scale, as in
[[Ark Transform]].

## Grill Log

- **Q:** Walk the tree recursively per node? **A:** No; per-node interpreted composition costs
  microseconds a node. Depth levels make every level one batch of lane kernels.
- **Q:** Store parents as World components? **A:** Parents are references, and World columns
  hold Float64 fields; the hierarchy keeps its own slot table keyed by entity handle.

## Referenced by

[[src/Ark/_MOC]] · [[Ark World]] · [[Ark Hierarchy Fixture]]
