---
type: module
path: "@root/scripts/ark-layers.mjs"
fidelity: Active
aliases: [Ark Layer Gate]
tags: [module, ark, dependencies]
---
# Ark Layer Gate

## Purpose and algorithm

Scan regular Pudu files under the shipped library or `--root`, using [[Application Layer Model]]'s
declaration scanner. Require module identity to match root-relative path. Empty/malformed roots
fail. Run [[Ark Layer Model]] and emit a concise count/finding report or `--json`. A model finding
or scan/argument error exits nonzero. Skip filesystem links; sort directory entries deterministically.

## Resolved Grill Log

- **Q:** Count a missing source root as a clean graph? **A:** No; filesystem failures are explicit.
- **Q:** Treat the scanner as compiler acceptance? **A:** No; focused engine execution is separate.

## Referenced by

[[Ark Dependency Layers]] · [[Ark Layer Model]] · [[Ark Layer Tests]] · [[src/_MOC]]
