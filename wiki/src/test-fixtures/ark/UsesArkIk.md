---
type: module
path: "@root/test-fixtures/ark/UsesArkIk.pudu"
fidelity: Active
aliases: [Ark Ik Fixture]
tags: [module, ark, test, animation]
---
# Ark Ik Fixture

Checks [[Ark Ik]] two-bone solutions against analytic positions: a right-angle elbow with the pole
on either side, full extension with its shortfall, a target inside the minimum reach folding the
limb, and a target at the root keeping the limb's direction; bone lengths preserved to rounding;
the bone rotations carrying the old bone directions onto the new ones; soft reach equal to the
hard reach at the band's start, continuous in slope there, and below full extension far beyond
it. Checks [[Ark Quaternion]] `between` for aligned, perpendicular and opposite directions and
zero refusal. Checks FABRIK convergence on a four-joint chain with lengths and root kept, an
unreachable target straightening the chain in one pass, and every refusal. Prints
`ark ik: ok`.

## Referenced by

[[Ark Animation Gate]] · [[Ark Ik]]
