---
type: module
path: "@root/test/ark-game.mjs"
fidelity: Active
aliases: [Ark Game Gate]
tags: [module, ark, game, test]
---

# Ark Game Gate

## Purpose and interface

Runs [[Ark Game Fixture]] with exact output, checks formatting of the fixture and both Game
modules, requires a positioned `E3001` for a text zoom factor, and confirms both modules ship in
the source archive. Registered in CI and the local gate.

## Resolved Grill Log

- **Q:** Rely on the checkout for the nested `Game/` directory? **A:** No; the archive check
  failed before the glob was added, which is the failure it exists to catch.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Game Fixture]]
