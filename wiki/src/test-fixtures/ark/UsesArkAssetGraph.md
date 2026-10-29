---
type: module
path: "@root/test-fixtures/ark/UsesArkAssetGraph.pudu"
fidelity: Active
aliases: [Ark Asset Graph Fixture]
tags: [module, ark, assets, graph, test]
---

# Ark Asset Graph Fixture

## Purpose and interface

Check deterministic dependency order and reverse closure through a diamond, an unrelated node,
leaf/unknown roots, empty input, duplicate IDs/edges, missing dependencies, self/multi-node cycles
and blocked descendants. A 1,000-node chain verifies depth-independent traversal and exact output
order. Malformed public graph references/order must terminate with typed errors. Successful
execution prints `ark asset graph: ok` and returns zero.

## Resolved Grill Log

- **Q:** Verify only that each dependency appears somewhere? **A:** No; assert exact deterministic
  order and unique transitive closures, then exercise the degree-accounting failure families.

## Referenced by

[[Ark Asset Dependencies]] · [[Ark Assets Gate]] · [[src/Ark/_MOC]]
