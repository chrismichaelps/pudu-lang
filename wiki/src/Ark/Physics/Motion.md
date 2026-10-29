---
type: module
path: "@root/lib/Ark/Physics/Motion.pudu"
fidelity: Active
aliases: [Ark Swept Motion]
tags: [module, ark, physics]
---
# Ark Swept Motion

## Contract

Layer-three query-driven geometric movement depends only on Ark.Math and Std.Math.Float.
`Contact` holds a fraction in [0,1] and outward unit normal. `Movement` holds position,
unapplied remaining motion, post-contact full-call response, remainingFraction, query/contact counts
and exhausted. Divide response by the original call duration for post-contact velocity; average
position change cannot recover it. On exhaustion, remaining = response*remainingFraction and
remainingFraction is the product of unconsumed hit fractions. Completed moves report zero fraction
(including stationary time after a stop), retaining response even on a miss or endpoint contact. `Error[E]` distinguishes
InvalidInput, InvalidContact, NumericRange and QueryFailed(E).
`move[E](position, displacement, maxQueries, sweep)` returns Result[Movement, Error[E]].
The callback receives current origin and unresolved displacement, and returns the earliest
blocking Contact, None for clear motion, or its own typed error. It captures fixed shape,
world/filter/skin settings. Backend errors retain their payload; no controller state mutates.

Validate finite positions/displacements and budgets 1..16, including final endpoint range.
Zero motion completes without a callback (it performs no overlap test). A contact needs finite
fraction in [0,1], a normal whose length differs from one by at most 1e-9, and strictly inward
motion. Normalize the admitted normal using its already checked near-unit length before clipping. Move only the reported fraction.
Retain the remaining fraction and all contact normals for this call. Choose the closest
feasible residual among interior, each face, each pairwise crease and zero. Scale by the largest absolute component
before dot products/scoring, preserving overflowing Euclidean magnitudes when components fit; projected-candidate feasibility admits negative scaled dot down to 1e-12. The unchanged incoming
direction requires nonnegative dots; slack must never bypass a shallow inward contact.
Three independent constraints may stop motion. Duplicate/parallel planes need no inverse.
A miss applies the residual; a zero clipped residual completes. Exhaustion returns position
and residual/time fraction explicitly, never applies unresolved travel. Complete underflow of a nonzero
residual or projected response vector, or an overflowing response, is NumericRange. Each callback consumes one budget.

## Limits and performance

At most 16 normals; O(k^3) feasibility work per clipping step with k contacts, bounded storage O(k).
The common no-hit case performs one callback and no constraint enumeration. Retained planes
are conservative within a single call; a finite obstacle's old plane may restrict later motion.
This is geometric sliding, not a full locomotion policy. No gravity, floor/stepping, penetration
recovery, rotating sweep, native layout or game-scale throughput is claimed. A callback must
actually report earliest collision; validating its record cannot establish scene correctness.

## Resolved Grill Log

- **Q:** Import a particular shape query? **A:** No; capture shape and backend in the callback so
  scene and finite-obstacle queries share the solver without World/device dependencies.
- **Q:** Swallow a failed query as clear travel? **A:** No; wrap its original typed payload.
- **Q:** Apply remaining motion at the limit? **A:** No; return exhausted with unapplied residual.
- **Q:** Sequential projections at a corner? **A:** Enumerate feasible faces/creases/zero to keep
  earlier constraints; sequential clipping can re-enter an earlier wall.
- **Q:** Infer end velocity from total travel? **A:** No; retain the deflected full-call response
  and budget time fraction. One projection updates response and derives remaining by scalar time.
- **Q:** Infer grounded from a contact? **A:** No; support and walkability need a separate floor policy.

## Referenced by

[[Ark Engine]] · [[src/Ark/_MOC]] · [[Ark Motion Fixture]] · [[Ark Motion Delivery]]
