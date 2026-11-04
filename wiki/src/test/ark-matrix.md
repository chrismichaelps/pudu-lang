---
type: module
path: "@root/test/ark-matrix.mjs"
fidelity: Active
aliases: [Ark Matrix Gate]
tags: [module, ark, test]
---
# Ark Matrix Gate

## Purpose and algorithm

Use an explicitly supplied compiler and repository library root to check and run
[[Ark Matrix Fixture]], assert exact output and check formatting of changed Pudu sources.
Temporary wrong-vector-dimension and Float32 clients must report E3001 at their call lines.
Create a temporary Cabal source archive and require nested Ark/Math/Matrix.pudu inclusion.
Clean temporary files on every exit. This is focused interpreted conformance, not native evidence.
[[Repository Gates]] and [[Pudu Continuous Verification]] invoke this against their built compiler.

## Resolved Grill Log

- **Q:** Build the complete release archive again? **A:** No; this change only adds a nested
  data-file glob, so check that source archive and focused module acceptance.
- **Q:** Rerun full gates? **A:** No; only affected math and packaging contracts are checked.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Matrix]] · [[Ark Matrix Fixture]] · [[Ark Matrix Delivery]]
