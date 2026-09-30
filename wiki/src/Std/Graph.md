---
type: module
path: "@root/lib/Std/Graph.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, graph]
aliases: [Std Graph]
---
# Std Graph
## Purpose
Own directed graphs over ordered nodes: construction, degree and adjacency queries, breadth-first
reachability, topological order, cycles, strongly connected groups, components, and shortest paths
counted in edges.
## Interface
A graph is a node set and a [[Std MultiMap]] of edges. Walks take the next node from a
[[Std Deque]], and every query answers arrays in a deterministic order.
## Governance and algorithm
`roots` gathers every node an edge points at in one pass over the edges, then keeps the nodes it
did not gather. `topologicalOrder` counts in-degrees once. Walk loops carry a guard derived from the
node count, so a malformed graph cannot loop forever.
## Grill Log
- **Q:** Answer `roots` by asking `inDegree` of each node? **A:** No. _Rationale:_ `inDegree` walks
  every edge, so `roots` walked every edge once per node. _Rejected:_ storing reverse edges, which
  doubles every insertion to serve one query.
## Referenced by
[[src/Std/_MOC]] · [[architecture/STDLIB]]
