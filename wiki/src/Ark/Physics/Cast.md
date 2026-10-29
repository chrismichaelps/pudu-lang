---
type: module
path: "@root/lib/Ark/Physics/Cast.pudu"
fidelity: Active
aliases: [Ark Capsule Box Cast]
tags: [module, ark, physics]
---
# Ark Capsule Box Cast

`capsuleBox(request: &CapsuleBox) -> Result[Option[Hit], Error]` translates a capsule segment
against a finite axis-aligned box. Request fields: start/end segment endpoints, positive radius,
displacement over the whole interval, box minimum/maximum, positive tolerance smaller than the
radius, and maxIterations in [1,128]. A point segment is a sphere. Capsule segments can have any orientation; box axes can have
zero width. Rotation during the sweep is not represented.

`Hit` reports fraction in [0,1], outward unit normal from box to capsule, point on the box and
iterations used. `Error` distinguishes InvalidInput, NumericRange, InitialOverlap and IterationLimit.
Invalid public records are refused. Initial penetration deeper than tolerance is InitialOverlap,
including zero segment-box distance. Initial touching that moves away or tangentially is a miss;
inward initial touching is a hit at zero. Static separated shapes are a miss.

Each bounded iteration obtains [[Ark Segment Box Distance]] witnesses. Their separating normal
supplies closing speed; advance by separation/closing speed. For fixed-orientation convex objects,
this supporting-plane bound cannot skip a first impact. A nonpositive closing speed establishes a
miss; a positive bound beyond fraction one also establishes a miss (including positive overflow of
that bound). Separation within tolerance reports a hit, so near contacts may be conservative by
that explicit spatial tolerance. A stalled fraction or exhausted budget returns IterationLimit,
never a miss. Non-finite geometry/intermediates, later penetration deeper than tolerance, and a
tolerance below 16 machine epsilons times the largest input magnitude return NumericRange. Advancement reserves
half the tolerance before the supporting plane to absorb ordinary rounding. Capsule endpoints at
the end of the requested displacement must be finite before iteration begins.

The mathematical distance kernel has a constant seven-interval bound; cast work is proportional
to the explicit iteration budget. No host physics middleware, scene indexing or native-throughput
claim is introduced. Scene broadphase, controller composition, mesh casts and depenetration remain
engine obligations; this is their checked finite-box primitive.

## Resolved Grill Log

- **Q:** Return None after convergence fails? **A:** No; convergence failure is an explicit typed error.
- **Q:** Infer a normal from a penetrating zero-distance witness? **A:** No; refuse initial overlap.
- **Q:** Use only the capsule's center? **A:** No; sweep its entire translated segment plus radius.
- **Q:** Inflate box extents and accept the slab hit? **A:** No; that blocks empty space near corners.
- **Q:** Introduce another canonical box type? **A:** No; accept lower/upper vectors at this boundary.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Cast Fixture]] · [[Ark Cast Gate]] · [[Ark Cast Delivery]]
