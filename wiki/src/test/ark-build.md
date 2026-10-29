---
type: module
path: "@root/test/ark-build.mjs"
fidelity: Active
aliases: [Ark Build Gate]
tags: [module, ark, build, test]
---

# Ark Build Gate

## Purpose and interface

Runs [[Ark Build Fixture]] with exact output, checks formatting of the fixture, [[Ark Build]],
[[Ark Pack]] and [[Ark Virtual Files]], requires a positioned `E3001` for text passed as pack
bytes, and confirms the modules ship in the source archive. Registered in CI and the local gate.

## Resolved Grill Log

- **Q:** Leave the changed VFS to the platform gate alone? **A:** No; this gate formats and ships
  it too, since the pack mount is part of what it verifies.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Build Fixture]]
