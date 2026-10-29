---
type: module
path: "@root/test/ark-ui.mjs"
fidelity: Active
aliases: [Ark UI Gate]
tags: [module, ark, ui, test]
---

# Ark UI Gate

## Purpose and interface

Runs [[Ark UI Fixture]] with exact output, checks formatting of the fixture and [[Ark UI]],
requires a positioned `E3001` for a text rectangle width, and confirms the module ships in the
source archive. Registered in CI and the local gate.

## Resolved Grill Log

- **Q:** Check rendering only by command counts? **A:** No; the fixture checks rendered pixels.

## Referenced by

[[src/Ark/_MOC]] · [[Ark UI Fixture]]
