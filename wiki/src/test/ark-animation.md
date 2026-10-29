---
type: module
path: "@root/test/ark-animation.mjs"
fidelity: Active
aliases: [Ark Animation Gate]
tags: [module, ark, animation, test]
---

# Ark Animation Gate

## Purpose and interface

Runs [[Ark Animation Fixture]] and [[Ark Ik Fixture]] with exact output against an explicit
compiler and the checkout library, checks formatting of the fixtures, [[Ark Ik Benchmark]] and
the four Animation modules, requires positioned `E3001`s for a text blend weight and a text IK
softness, and confirms the modules ship in the source archive. `--bench` prints nanoseconds per
single, batched and chain solve. Registered
in CI and the local gate.

## Resolved Grill Log

- **Q:** Trust the checkout for shipping? **A:** No; the nested `Animation/` glob is checked in
  the actual source archive.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Animation Fixture]]
