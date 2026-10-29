---
type: module
path: "@root/lib/Ark/Physics/Character.pudu"
fidelity: Active
aliases: [Ark Character Movement]
tags: [module, ark, physics]
---
# Ark Character Movement

## Purpose and interface

Pure kinematic capsule movement inside a convex intersection of plane halfspaces. Depends only
on [[Ark Math]] and Std.Math.Float; no world/device state. Provisional public API (#714).
`Plane` stores normal and offset, with admissible centers on normal dot position >= offset plus
capsule support. `plane(normal, point)` checks and normalizes coefficients. `Capsule` stores
position, radius, halfHeight and up; halfHeight includes the hemispheres and must be >= radius.
`move(capsule, displacement, planes, skin, maxSlides, groundDot) -> Option[Movement]` normalizes
up and public plane coefficients once. Radius is positive, skin nonnegative, groundDot in (0,1],
maxSlides in [1,16]; every scalar/vector/intermediate must be finite. Initial penetration beyond
1e-9 times max(1,radius) is refused; this operation does not depenetrate.

Each sweep scans prepared planes using support radius + (halfHeight-radius) abs(normal dot up).
Only inward displacement exceeding the admission tolerance can collide; smaller negative
roundoff is admitted within that same final-clearance bound. Earliest time wins, with input order
breaking ties. Advance to the skin boundary, retain unconsumed motion, then project against all encountered normals.
Projection enumerates the original vector, single-plane projections, pairwise crease projections
and zero; choose the feasible vector closest to the original. Scale motion to unit magnitude
before scoring. Feasibility permits 1e-12 directional roundoff; subsequent sweeps still test every
plane before any movement. Near-parallel crease directions that cannot normalize are skipped.
No solver pass may increase the residual magnitude. Work is bounded by maxSlides and the contact
set (at most 16); scene plane scans are linear, contact projection at most cubic in that bound.

`Movement` contains final position, unconsumed remaining displacement, contacts, grounded and
exhausted. A zero projection is a completed blocked move. Exhausted means the iteration budget
ended with pending movement; pending movement is never applied. Grounded requires final support
within skin plus admission tolerance and normal dot up >= groundDot; ceilings and vertical walls
never ground. Gravity, jumping and speed policy belong to the caller. Ramps can redirect movement
upward; this geometric operation does not claim grounded walking or falling policy.

## Resolved Grill Log

- **Q:** Approximate a capsule as a sphere? **A:** No; analytic support includes its oriented segment.
- **Q:** Project only against the last wall? **A:** No; all active constraints prevent corner reentry.
- **Q:** Apply motion left after the budget? **A:** No; report it explicitly without crossing geometry.
- **Q:** Infer grounded from an earlier collision? **A:** No; classify support at the final position.
- **Q:** Claim general scene collision? **A:** No; these are convex plane boundaries, not finite obstacles.
- **Q:** Copy foreign movement policy? **A:** No; this library owns a small explicit geometric contract.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Character Fixture]] · [[Ark Character Gate]] · [[Ark Character Delivery]]
