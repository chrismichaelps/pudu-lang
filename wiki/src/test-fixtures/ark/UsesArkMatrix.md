---
type: module
path: "@root/test-fixtures/ark/UsesArkMatrix.pudu"
fidelity: Active
aliases: [Ark Matrix Fixture]
tags: [module, ark, test]
---
# Ark Matrix Fixture

## Purpose and algorithm

Main checks [[Ark Matrix]] with explicit asymmetric matrices and expected numeric answers.
Cover Vec4 construction, Mat3 numeric multiplication/transform, Mat4 all-component transform,
identities on both sides, transpose involution, noncommuting translation/scaling composition,
direction versus point translation, perspective division and zero/non-finite/overflow refusal.
Print exactly `ark matrix: ok` and return zero; a failed named check panics.

## Resolved Grill Log

- **Q:** Test identity only? **A:** No; asymmetric products detect transposition and composition mistakes.
- **Q:** Accept a successful exit without output? **A:** No; the gate checks exact completion output.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Matrix]] · [[Ark Matrix Gate]]
