---
type: module
path: "@root/test/ark-animation.mjs"
fidelity: Active
aliases: [Ark Animation Gate]
tags: [module, ark, animation, test]
---

# Ark Animation Gate

## Purpose and interface

Runs [[Ark Animation Fixture]] with exact output against an explicit compiler and the checkout
library, checks formatting of the fixture and both Animation modules, requires a positioned
`E3001` for a text blend weight, and confirms both modules ship in the source archive. Registered
in CI and the local gate.

## Resolved Grill Log

- **Q:** Trust the checkout for shipping? **A:** No; the nested `Animation/` glob is checked in
  the actual source archive.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Animation Fixture]]
