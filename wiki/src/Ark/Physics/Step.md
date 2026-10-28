---
type: module
path: "@root/lib/Ark/Physics/Step.pudu"
fidelity: Active
aliases: [Ark Physics Step]
tags: [module, ark, physics]
---
# Ark Physics Step

## Purpose and interface

`step(bodies, dt, iterations) -> Option[(Bodies, StepStats)]`: box bounds and native broadphase
pairs at current positions, batched contacts from [[Ark Contact]], gravity applied to movable
velocity lanes, then `iterations` colored Gauss–Seidel impulse passes. Restitution uses the larger
material value; Coulomb friction uses their geometric mean and is bounded by the normal impulse.
Updated velocities advance positions; one correction pass removes 80% of penetration beyond a
0.005 slop. `StepStats` reports pairs, contacts and batches.

For each contact, divide both inverse masses by their maximum before constructing the constraint.
The common scale cancels from impulse application; their sum then lies in [1, 2], avoiding
overflow when individually finite inverse masses have an unrepresentable sum.

Greedy coloring follows contact order. Each batch contains no repeated body except the static
plane slot. The first 62 colors use bit masks; every overflow contact receives its own singleton
batch, so contact degree has no correctness cap. Batches execute in color order, not global pair
order; execution is deterministic for identical body insertion and plane order.

## Grill Log

- **Q:** Sum raw inverse masses? **A:** No; scale the pair first. Finite admitted inverse masses
  can overflow when added, even though the collision response is representable.

- **Q:** Merge contacts once the color mask fills? **A:** No; singleton overflow batches retain
  sequential impulse semantics for arbitrarily high contact degree.

- **Q:** Correct positions every iteration? **A:** No; one pass after velocity iterations keeps
  stacks stable without adding energy.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Physics Fixture]]
