---
type: module
path: "@root/lib/Ark/Assets/Graph.pudu"
fidelity: Active
aliases: [Ark Asset Dependencies]
tags: [module, ark, assets, graph]
---

# Ark Asset Dependencies

## Purpose and interface

`Node` declares an asset ID and dependency IDs. `compile(nodes) -> Result[Graph, Error]` rejects
empty/NUL IDs, duplicate nodes/edges and missing dependencies before iterative Kahn ordering.
The graph contains a dependency-first order and reverse adjacency for every node. Initial ready
nodes follow input order; newly ready nodes append FIFO in authored dependent order, making the
result deterministic for the same declaration sequence. No recursion follows asset depth.

If ordering stalls, `Cycle` carries all unscheduled IDs in input order, including nodes blocked
downstream of a cycle; it does not claim to identify only strongly connected participants.
`affected(graph, id)` uses an iterative visited-set reverse traversal and filters the validated
topological order, returning the changed asset and every transitive dependent once. Unknown roots
and malformed graph references/order return typed errors rather than unbounded recursion.

Compilation and traversal use map lookups plus linear node/edge visits; ready selection never
repeatedly enumerates/sorts the entire ready set. Empty graphs compile successfully. This module
is pure and independent of file I/O, texture decoding and server revision state.

## Resolved Grill Log

- **Q:** Detect cycles with recursive DFS? **A:** No; user-authored dependency depth must not
  become host/interpreter stack depth. Kahn ordering and iterative closure keep traversal bounded.
- **Q:** Silently merge duplicate dependency declarations? **A:** No; reject them before degree
  accounting, preserving authored identity and preventing double decrements.
- **Q:** Label all stalled nodes as cycle members? **A:** No; the error explicitly includes
  blocked descendants, keeping its claim aligned with the ordering algorithm.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Asset Graph Fixture]] · [[Ark Assets Gate]]
