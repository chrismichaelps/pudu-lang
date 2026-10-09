---
type: module
path: "@root/test/app-layers.test.mjs"
fidelity: Active
tags: [test, application, graph]
aliases: [Application Layer Tests]
---
# Application Layer Tests

## Purpose and algorithm

Exact graph fixtures verify valid direction, upward imports, missing dependencies, unclassified
modules, duplicate identities, self and multi-module cycles, masked comments and literals, stable
report order and long dependency chains. The actual shipped library passes the command's path
and complete-graph checks. Temporary invalid library roots exercise unsuccessful command output.

## Resolved Grill Log

- **Q:** Check only the current graph? **A:** No; deliberate defect fixtures prove every refusal.
- **Q:** Accept a stable success code with missing files? **A:** No; exercise empty and invalid roots.

## Referenced by

[[Application Layer Model]] · [[Application Layer Gate]] · [[src/_MOC]]

## Bounded pool admission (#468)

A focused graph accepts pool → admission → session → protocol and rejects admission → pool. The hosting-layer diagnostic updates with the new explicit layer numbering.

Resolved Grill Log: executable refusal demonstrates the new layer's direction, rather than relying on a clean current graph alone.
