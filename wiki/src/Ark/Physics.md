---
type: module
path: "@root/lib/Ark/Physics.pudu"
fidelity: Active
aliases: [Ark Physics]
tags: [module, ark, physics]
---
# Ark Physics

## Purpose and interface

Rigid bodies as lanes keyed by entity handle. `Shape` is a kind and a half extent; the factories
`sphere(radius)` and `box(half)` build them and the const `SHAPE_FACTORIES` table maps a kind
name to its factory for data-driven content (`shapeOf(kind, size)`). `Body` describes position,
velocity, mass (zero is static), restitution, friction and shape. `Bodies` holds per-body lanes
(position, velocity, half extent, inverse mass, restitution, friction, a movable mask), kinds,
static planes and gravity: `world(gravity)`, `add -> Option` (refuses a duplicate entity,
negative mass or out-of-range material), `remove -> Option`, `addPlane -> Option`, `count`,
`position`, `velocity`, `setVelocity`, `applyImpulse` (velocity change by inverse mass; static
bodies ignore it) and `slotOf`.

Admission validates public shape records by looking up their factory and requiring the canonical
shape to match. Material values must be ordered within [0, 1], which rejects NaN. Positive mass
must have a finite inverse. Velocity updates and impulse results must remain finite; invalid
updates answer None before storing lanes. Zero mass remains static with zero initial velocity.

## Grill Log

- **Q:** Trust a public shape record to have come from a factory? **A:** No; admission checks
  the factory result. Record construction is public and cannot establish the invariant.
- **Q:** Permit an infinite inverse mass or NaN material? **A:** No; reject at admission rather
  than allowing lane kernels to contaminate other bodies.

- **Q:** Rotational dynamics now? **A:** Not in this slice: bodies translate; boxes stay axis
  aligned. Angular state is a later slice with oriented boxes; the contracts here do not change.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Physics Fixture]]
