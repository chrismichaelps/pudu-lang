---
type: module
path: "@root/test/desktop-configure.mjs"
fidelity: Active
aliases: [Desktop Configure Gate]
tags: [module, test, desktop]
---
# Desktop Configure Gate

## Purpose and algorithm

Run [[Desktop Configure Fixture]] with the supplied compiler and require its exact output: one
specific message per refused setting, then that valid settings were refused for the missing
window. The output is the same on every target because settings are checked before any window
is looked up. In a private temporary root, require `desktopConfigure` called with a Float density
to fail type checking with a positioned E3001. Check the fixture's formatting.

## Referenced by

[[Repository Gates]] · [[Eval Desktop]]
