---
type: module
path: "@root/test-fixtures/stdlib/UsesMobileMaterial.pudu"
fidelity: Active
tags: [module, fixture, stdlib, mobile, native]
aliases: [Uses Mobile Material]
---

# Uses Mobile Material

## Purpose and interface

Stdlib fixture for the material additions of [[Std Mobile View]], their instruction in [[Std Mobile Stream]] and the material codes of [[Std Mobile Theme]]. Its entry drives `mount` and `update` through the checks below and answers the number of checks that held: 5. The data spec `test/Pudu/Compiler/Program/Eval/DataSpec.hs` asserts that count.

Checks:
1. A surfaced label mounts CREATE kind 9, MATERIAL with the regular code 2, then the label built and appended, then ROOT.
2. A changed material alone is exactly one 12-byte MATERIAL.
3. An unchanged tree writes nothing.
4. A changed child kind replaces only the child and keeps the material node.
5. The three materials encode 1, 2 and 3.

## Invariants

- Each check compares an exact word or byte sequence, never a length alone.
- The fixture makes no foreign call. It runs interpreted and as native C11 code, and both must agree.

## Negative Logic

- No platform host is started, so the fixture runs without a simulator. The realization of a material (glass or blur) is checked by the simulator run of [[Native Glass Example]], not here.
- Checks do not depend on the order of the platform's own default colors.

## Dependencies and consumers

Depends on [[Std Mobile View]], [[Std Mobile Stream]] and [[Std Mobile Theme]]. Its checks mirror the surface contract that [[iOS Host Material]] realizes.

## Resolved Grill Log

- **Q:** Check bytes or summaries? **A:** Exact words, as for [[Uses Mobile List]]. A summary such as "contains a MATERIAL" would pass a wrong material code or a wrong node id.
- **Q:** Why check a material change alone? **A:** A change to only the material must write exactly one MATERIAL instruction and nothing else; a combined check would hide a commit that rebuilt the surface.

## Referenced by

[[Std Mobile View]] · [[Std Mobile Stream]] · [[Std Mobile Theme]] · [[Native iOS Materials Delivery]]
