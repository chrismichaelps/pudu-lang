---
type: module
path: "@root/test-fixtures/ark/UsesArkPhysicsBoundary.pudu"
fidelity: Active
aliases: [Ark Physics Boundary Fixture]
tags: [module, ark, physics, test]
---

# Ark Physics Boundary Fixture

## Purpose and interface

Focused regressions for physics admission and solver batching. Invalid public shape records,
NaN materials, overflowing inverse mass and non-finite velocity or impulse updates answer None.
An ordinary dynamic body and static-body velocity rules remain accepted. A body with 64 contacts
requires 64 disjoint batches, including contacts beyond the 62-bit mask capacity. Successful
elastic response reverses velocity from +1 to −1 without injecting energy. Finite inverse mass
and closed material interval boundaries remain accepted; a finite impulse whose result overflows
is refused.
Two tiny but admitted masses collide elastically with finite reversed velocities despite their
raw inverse-mass sum overflowing. Successful execution prints `ark physics boundaries: ok`
and returns zero.

## Resolved Grill Log

- **Q:** Test a private color helper directly? **A:** No; public step statistics expose the
  required disjoint batches for one body sharing every contact.
- **Q:** Test only valid factory-produced shapes? **A:** No; public records can bypass factories,
  so admission must reject fabricated invalid shapes.

## Referenced by

[[Ark Physics]] · [[Ark Physics Step]] · [[Ark Physics Continuation]] · [[src/Ark/_MOC]]
