---
type: module
path: "@root/test-fixtures/ark/UsesArkPhysicsAngular.pudu"
fidelity: Active
aliases: [Ark Physics Angular Fixture]
tags: [module, ark, physics, test]
---

# Ark Physics Angular Fixture

A sphere sliding on a frictional plane settles at 5/7 of its speed with its contact point at
rest; a free sphere's orientation integrates π radians in one second; frictionless contact and
boxes never spin; non-finite spin is refused; removal keeps angular lanes aligned. Prints
`ark physics angular: ok`. Run by [[Ark Physics Gate]].

## Resolved Grill Log

- **Q:** Check only that spin is nonzero? **A:** No; the analytic 5/7 result and zero contact
  slip fail if the rotational effective mass is removed, which a mutation confirms.

## Referenced by

[[Ark Physics Step]] · [[Ark Physics Gate]]
