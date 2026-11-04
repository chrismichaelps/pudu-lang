---
type: module
path: "@root/test/ark-water.mjs"
fidelity: Active
aliases: [Ark Water Gate]
tags: [module, ark, test, water]
---
# Ark Water Gate

## Purpose and interface

Run node test/ark-water.mjs <optimized-compiler>. Read WaveTank.pudu and verify
one exact exported entry point and literal cell/coefficient declarations. Rename
only that entry point in private scratch; append an unforced conformance entry.
The production tables, update, coefficients, damping and clamp stay unchanged.
Record the source digest in the passing report and remove private scratch on exit.

## Numerical and execution contracts

Use actual tables and advance. Reset input steps to zero before each unforced
update so the existing scheduled-drop branch does not run. Initialize previous
height equal to height. Assert finite per-cell outputs, maximum absolute error
at most 1e-10 and peak displacement below 0.01 so clipping cannot hide instability.
Cover zero/constant equilibrium, low and high discrete reflecting modes at
multiple step counts, superposition and unforced mean displacement. The host
computes analytic modal coefficients independently from production lane kernels.

Run all cases through both evaluators with cache off, cold and warm. Check every
case output, process status, source-adapter assumptions and warm cache file inode
reuse. No desktop window or rendering is required. This gate validates the present
discrete wave update, not a bulk-water or free-surface fluid solver.

## Resolved Grill Log

A fixed screenshot misses wrong neighbour indices and phase errors; use analytic
mode trajectories. A clamp can conceal instability; keep the entire test in its
inactive range and reject non-finite values explicitly. Never replace or copy the
production step in the adapter. Small finite runs belong in local and hosted gates;
performance distributions and richer physical scenarios remain separate work.

## Referenced by

[[Ark Water Validation]] · [[Repository Gates]] · [[Pudu Continuous Verification]] · [[src/Ark/_MOC]] · [[Water Validation Delivery]]
