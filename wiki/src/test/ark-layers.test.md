---
type: module
path: "@root/test/ark-layers.test.mjs"
fidelity: Active
aliases: [Ark Layer Tests]
tags: [module, ark, test]
---
# Ark Layer Tests

## Purpose and algorithm

Node tests cover all fifteen root classifications, accepted lower/same-root edges, peer/upward
refusals, reverse shared-library edges, unknown roots, missing imports, duplicate declarations,
cycles/self-cycles and a long iterative same-root chain. Check deterministic JSON under input
reversal. Actual CLI fixtures cover a valid library, exact failure output, path mismatch,
empty/missing roots and the checked-out shipped library. Temporary trees are removed on exit.

## Resolved Grill Log

- **Q:** Test only the current single engine root? **A:** No; synthetic modules cover the full catalog.
- **Q:** Assert only nonzero exit? **A:** No; inspect failure text so unrelated errors cannot pass.

## Referenced by

[[Ark Layer Gate]] · [[Ark Layer Model]] · [[Ark Dependency Layers]] · [[src/_MOC]]
