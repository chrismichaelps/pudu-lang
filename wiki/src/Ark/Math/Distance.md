---
type: module
path: "@root/lib/Ark/Math/Distance.pudu"
fidelity: Active
aliases: [Ark Segment Box Distance]
tags: [module, ark, math]
---
# Ark Segment Box Distance

`segmentBox(start, end, minimum, maximum) -> Option[Closest]` supplies closest witnesses on a
segment and a finite axis-aligned box, plus their Euclidean distance. Zero-length segments and
zero-width box axes are valid. Refuse unordered bounds, non-finite input or unrepresentable
intermediates. Uses [[Ark Math]] and Std.Math.Float; no scene or device dependencies.

The segment parameter is partitioned by its six possible slab crossings into at most seven
intervals. Within each interval the squared distance is a quadratic over only the outside axes.
Minimize it analytically and clamp to that interval, then compare finite witness distances.
Scale active direction coefficients before products to avoid squaring raw large/tiny coordinates.
Duplicate crossing parameters produce empty intervals and are skipped. Flat intervals use the
left endpoint. Input order resolves equal distances. No sampling approximation is used.

## Resolved Grill Log

- **Q:** Treat a capsule as its expanded box? **A:** No; closest witnesses retain rounded edges.
- **Q:** Square unscaled coordinate differences? **A:** No; scale the quadratic coefficients and
  use checked scaled vector length for witness comparison.
- **Q:** Assume the nearest point is an endpoint? **A:** No; interval minima include the segment interior.
- **Q:** Hide an overflowing intermediate in a miss? **A:** No; return None, which the cast maps to a range failure.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Capsule Box Cast]] · [[Ark Cast Fixture]] · [[Ark Cast Delivery]]

A point segment returns its clamped witness directly before building slab intervals.
Resolved Grill Log: sphere casts need no quadratic solve; retain the same finite admission and
witness contract and validate both degenerate and nondegenerate cases in the cast fixture.
