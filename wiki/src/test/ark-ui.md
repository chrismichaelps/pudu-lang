---
type: module
path: "@root/test/ark-ui.mjs"
fidelity: Active
aliases: [Ark UI Gate]
tags: [module, ark, ui, test]
---

# Ark UI Gate

## Purpose and interface

Runs [[Ark UI Fixture]], [[Ark Inspect Fixture]] and [[Ark Text Fixture]] with exact output,
checks formatting of the fixtures, [[Ark Text Benchmark]], [[Ark UI]], [[Ark Inspect]] and [[Ark
Text]], requires positioned `E3001`s for a text rectangle width, a numeric inspector path and a
text glyph scale, and confirms the modules ship in the source archive. `--bench` times layout and
drawing for a screen of text. Registered in CI and the local gate.

## Resolved Grill Log

- **Q:** Check rendering only by command counts? **A:** No; the fixture checks rendered pixels.

## Referenced by

[[src/Ark/_MOC]] · [[Ark UI Fixture]]
