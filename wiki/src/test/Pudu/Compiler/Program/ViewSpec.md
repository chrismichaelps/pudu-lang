---
type: module
path: "@root/test/Pudu/Compiler/Program/ViewSpec.hs"
fidelity: Active
tags: [module, test, stdlib]
aliases: [Program View Spec]
---
# Program View Spec

## Purpose and interface
Export viewProperties, a registry of IO properties evaluating the shipped view fixtures.

## Algorithm and invariants
Use the common complete-program runner; require no compile/runtime diagnostics and the exact assertion-group count.
Existing fixtures prove unchanged behavior; boundary fixtures prove arithmetic refusals, snapshots, layout observations and raw UTF-8 byte operations.
The test process selects the evaluator mode, so focused runs execute both tree and compiled.

## Resolved Grill Log
A fixture returning fewer successes must fail the property. Register the module in the Cabal manifest and Program Spec so full gates execute identical checks. No new dependencies or test-only interpreter.

## Referenced by
[[Program Spec]] · [[Pudu Test Cabal Manifest]] · [[UsesViewBoundaries]] · [[UsesStringViewSearch]]

Include [[UsesIterViews]] with six assertion groups, lazy traversal counts and restartability.
