---
type: module
path: "@root/test/ark-ui.mjs"
fidelity: Active
aliases: [Ark UI Gate]
tags: [module, ark, ui, test]
---

# Ark UI Gate

## Purpose and interface

Runs [[Ark UI Fixture]] and [[Ark Inspect Fixture]] with exact output, checks formatting of the
fixtures, [[Ark UI]] and [[Ark Inspect]], requires positioned `E3001`s for a text rectangle
width and a numeric inspector path, and confirms both modules ship in the source archive. Registered in CI and the local gate.

## Resolved Grill Log

- **Q:** Check rendering only by command counts? **A:** No; the fixture checks rendered pixels.

## Referenced by

[[src/Ark/_MOC]] · [[Ark UI Fixture]]
