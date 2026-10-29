---
type: module
path: "@root/test/ark-net.mjs"
fidelity: Active
aliases: [Ark Net Gate]
tags: [module, ark, net, test]
---

# Ark Net Gate

## Purpose and interface

Runs [[Ark Net Fixture]] with exact output, checks formatting of the fixture and both Net modules,
requires a positioned `E3001` for a text quantization step, and confirms both modules ship in the
source archive. Registered in CI and the local gate.

## Resolved Grill Log

- **Q:** Exercise real sockets here? **A:** No; the modules are transport-agnostic, so the gate
  checks protocol behavior deterministically.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Net Fixture]]
