---
type: module
path: "@root/test-fixtures/ark/UsesArkGround.pudu"
fidelity: Active
aliases: [Ark Ground Fixture]
tags: [module, ark, physics, test]
---
# Ark Ground Fixture

Exercise [[Ark Capsule Support]] through an analytic flat-plane query plus explicit boundary
witnesses. Cover landing and stored horizontal velocity, unsupported/rising transition to Falling,
cardinal/non-cardinal arbitrary up including aligned floors at minUpDot=1, inclusive slope threshold, strict footprint/lower-hemisphere boundaries, endpoint and
zero-fraction support, consecutive oblique settlement without false rising, tiny true rising, typed query failure, invalid settings/contact and numeric range including combined endpoint and velocity-projection overflow. Scaled
capsules exercise 1e-200..1e200. Output exactly `ark ground: ok`.

## Resolved Grill Log

- **Q:** Test only successful floor snaps? **A:** No; side/edge/ceiling/steep and lost-support cases
  must stay airborne, while positive up velocity proves no query occurred.
- **Q:** Use hard-coded world Z for floor tests? **A:** No; rotate gravity and witness coordinates.

## Referenced by

[[Ark Capsule Support]] · [[Ark Ground Gate]] · [[src/Ark/_MOC]]
