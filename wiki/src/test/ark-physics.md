---
type: module
path: "@root/test/ark-physics.mjs"
fidelity: Active
aliases: [Ark Physics Gate]
tags: [module, ark, physics, test]
---

# Ark Physics Gate

## Purpose and interface

Run the scenario and boundary fixtures against an explicit compiler with the checkout library.
Require exact success output, formatter stability of the physics modules and both fixtures,
and a positioned E3001 rejection for a non-numeric mass. Check source distribution inclusion of
all four physics modules. Temporary refusal programs and archives are removed after verification.
The gate is registered in CI and the local repository gate; local development runs only this
focused gate, without rebuilding or invoking the full suite.

## Resolved Grill Log

- **Q:** Assert machine-specific solver timings in CI? **A:** No; timings belong to consumed-result
  benchmarks. This gate verifies contracts and durable failures.
- **Q:** Rely on unpositioned checker failure? **A:** No; require both E3001 and the authored call line.

## Referenced by

[[src/Ark/_MOC]] · [[Ark Physics Fixture]] · [[Ark Physics Boundary Fixture]] · [[Ark Physics Continuation]]
