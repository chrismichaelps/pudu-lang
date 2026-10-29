---
type: module
path: "@root/test-fixtures/ark/UsesArkCharacter.pudu"
fidelity: Active
aliases: [Ark Character Fixture]
tags: [module, ark, physics, test]
---
# Ark Character Fixture

Exercise [[Ark Character Movement]] through the public API: free motion, high-speed plane
stopping, tangential sliding, two-wall corners, oriented capsule support, arbitrary up, final
grounding, skin separation, outward motion, bounded exhaustion and initial-overlap refusal.
A deterministic sequence of room moves checks containment and non-increasing travel, including
repeated contact. Invalid radii, dimensions, normals, offsets, vectors and budgets answer None. Exact output:
`ark character: ok`. Deterministic numerical assertions avoid timing-dependent requirements.

## Resolved Grill Log

- **Q:** Only test that a wall stops movement? **A:** No; preserve tangential travel and corner feasibility.
- **Q:** Treat non-finite refusal as a panic? **A:** No; assert None through the public API.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Character Gate]] · [[Ark Character Delivery]]
