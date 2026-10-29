---
type: module
path: "@root/test-fixtures/ark/UsesArkMotion.pudu"
fidelity: Active
aliases: [Ark Motion Fixture]
tags: [module, ark, physics, test]
---
# Ark Motion Fixture

Exercise [[Ark Swept Motion]] with independent analytic point-plane queries: clear/zero motion,
wall slide including sub-tolerance inward motion, two-wall crease and three-wall stop, simultaneous contacts and plane permutations,
query budget residual/time and resume equivalence, endpoint response, overflow-safe direction
projection and subnormal refusal, exact counts, scales 1e-200..1e200, preserved query failures and invalid
contact fractions/normals/directions. Reject non-finite input, overflow and budgets outside 1..16.
Require exact stdout `ark motion: ok`. The finite-box adapter is additionally validated against
unmerged #719 in a temporary library overlay; this fixture remains runnable on dev alone.

## Resolved Grill Log

- **Q:** Use the solver's own projection to predict the fixture? **A:** No; use analytic plane times
  and explicit wall/corner endpoints, including invariance under reversed surface order.
- **Q:** Require a backend call on zero travel? **A:** No; zero travel is no overlap query.

## Referenced by

[[Ark Swept Motion]] · [[Ark Motion Gate]] · [[src/Ark/_MOC]]
