---
type: module
path: "@root/test-fixtures/ark/UsesArkPhysics.pudu"
fidelity: Active
aliases: [Ark Physics Fixture]
tags: [module, ark, physics, test]
---

# Ark Physics Fixture

## Purpose and interface

Public scenarios cover shape factories, invalid bodies and stale handles, free fall, plane
resting and bouncing, elastic body collisions, box stacks, friction and frictionless motion,
repeatable simulation, nearest ray hits, point overlap and static impulse behavior. Success prints
`ark physics: ok` and returns zero; failed assertions report their scenario name.

## Resolved Grill Log

- **Q:** Treat a benchmark as physical validation? **A:** No; explicit scene invariants exercise
  the solver and queries separately from performance measurements.
- **Q:** Include overflow batching here? **A:** The separate [[Ark Physics Boundary Fixture]] owns
  hostile numeric and high-degree regression cases, keeping scenario failures easy to identify.

## Referenced by

[[Ark Physics]] · [[Ark Contact]] · [[Ark Physics Step]] · [[Ark Physics Query]] · [[Ark Physics Gate]]
