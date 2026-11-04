---
type: module
path: "@root/lib/Ark/Physics/Ground.pudu"
fidelity: Active
aliases: [Ark Capsule Support]
tags: [module, ark, physics]
---
# Ark Capsule Support

## Public contract

Layer-three settlement depends only on Ark.Math and Std.Math.Float. Mode is Walking/Falling.
State carries capsule center position, velocity and mode. Settings carries up, radius,
halfHeight (including hemispheres), maxDistance, minUpDot, edgeInset and contactTolerance. Hit carries fraction,
outward unit normal and obstacle witness point. Support carries swept center position, normal,
point and distance. Settlement carries state plus optional Support.
`settle[E](&State, &Settings, sweep)` returns Result[Settlement, Error[E]]; errors distinguish
InvalidInput, InvalidContact, NumericRange and QueryFailed(E). The callback receives current
center and downward displacement, returning earliest Hit, clear None or its own typed error.
It must capture the same fixed capsule geometry and return initial penetration as an error.

Validate finite position/velocity, radius>0, halfHeight>=radius, maxDistance>0,
0<minUpDot<=1, 0<=edgeInset<radius and 0<contactTolerance<radius. Normalize a finite nonzero up vector.
Require radius, maxDistance and contactTolerance exceed 16*epsilon times the largest absolute center component;
refuse under-resolved geometry rather than claim support. Check original and fully probed capsule core endpoints for range.
An up velocity greater than 16*epsilon times the sum of absolute velocity/up dot-product terms returns
Falling unchanged without invoking the callback. Scale each term before summation to avoid
overflow. This excludes perpendicular components from the bound. Smaller positive projection residue is treated
as horizontal: otherwise a prior oblique-plane projection can falsely trigger falling.
Otherwise query once, preserving errors. Clear space returns Falling with unchanged position/velocity.

Validate finite fraction in [0,1], point and normal; normal length must be within1e-9 of one.
Normalize with that checked length. The slope dot must exceed its dot-product arithmetic bound
and reach minUpDot within that bound (16*epsilon times absolute dot terms); aligned arbitrary
gravity remains admissible at minUpDot=1. Steep/vertical/ceiling
contacts are valid query results but unsupported. Compute swept center = position-up*(fraction*
maxDistance). Translate witness relative to this center. The witness must be strictly below the
lower capsule core endpoint along up, and its gravity-horizontal distance must be strictly less
than radius-edgeInset. Require its distance from the lower core endpoint to differ from radius
by at most contactTolerance, refusing inconsistent lower-cap witnesses. Use scaled length rather than squaring world positions. Unsupported
contacts return Falling; malformed records and unrepresentable intermediates are explicit errors.
On support, snap the center to its swept position, store Walking with gravity-horizontal velocity
and return Support. Do not project stored walking velocity up a slope or synthesize upward boost.

Every exported type and function carries its own source documentation; the full API gate checks
this alongside fixture reachability.

## Boundaries and cost

Zero callbacks for rising states; at most one otherwise, constant scalar work and no source-level
collection allocation. maxDistance is explicit caller policy, not an implicit full-frame fall sweep.
Use a short landing distance after collision and a configured snap distance for grounded following.
The caller owns full-frame collision/gravity/horizontal movement, slope traversal, stepping,
perching retries, moving bases and penetration recovery. A rejected first contact is not a search
through that obstacle. No native scene throughput or bitwise cross-target determinism is claimed.

## Resolved Grill Log

- **Q:** Ground on any upward blocking normal? **A:** No; also require lower hemisphere and strict
  inset footprint, preventing side and near-rim contacts from grounding.
- **Q:** Pull a rising/jumping capsule back down? **A:** No; up velocity above its arithmetic
  error bound bypasses the probe. Use a velocity-relative bound, never a world-unit deadzone.
- **Q:** Hide query errors as loss of support? **A:** No; preserve QueryFailed payload.
- **Q:** Add gravity or stepping here? **A:** No; settle a post-movement state with one bounded query.
- **Q:** Fix numeric range with clamping? **A:** No; invalid and under-resolved geometry is refused.

## Referenced by

[[Ark Engine]] · [[src/Ark/_MOC]] · [[Ark Ground Fixture]] · [[Ark Ground Delivery]]
