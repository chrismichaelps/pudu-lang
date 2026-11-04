---
type: module
path: "@root/test/ark-ground.mjs"
fidelity: Active
aliases: [Ark Ground Gate]
tags: [module, ark, physics, test]
---
# Ark Ground Gate

Run [[Ark Ground Fixture]] with supplied compiler and checkout library; require exact output,
formatting/lint, positioned E3001 for a nonnumeric radius and actual archive inclusion of Ground.
CI and local gates run it. Optional third argument is a library containing #719 Cast/Distance:
copy those two modules into a temporary library with current Math/Ground and Std. An authored
non-point capsule adapter verifies a floor snap, loss of finite-box support, rising bypass and
preserved initial-overlap error. Remove scratch files on every exit; merge no dependency branch.

## Resolved Grill Log

- **Q:** Treat module-not-found as diagnostic success? **A:** No; require E3001 at the authored field.
- **Q:** Gate machine timing? **A:** No; record the consumed-result benchmark separately.

## Referenced by

[[Ark Ground Fixture]] · [[Repository Gates]] · [[Ark Ground Delivery]]
