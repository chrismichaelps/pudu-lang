---
type: module
path: "@root/test-fixtures/listeneridentity/ZServer.pudu"
fidelity: Active
grammar: "[[grammar/pudu]]"
tags: [module, test]
---

# Listener Identity ZServer

## Purpose and interface

Import the actual Std.Http.Server behind a project module ordered after PackageLog.Configuration.
Export `marker() -> Int` returning zero so the reverse entry loads the graph through this boundary.

## Algorithm and negative logic

The wrapper changes dependency traversal without altering standard-library definitions or relying
on textual import order that the formatter normalizes.

## Grill Log

- **Q:** Reverse import lines manually? **A:** No; use a project wrapper to preserve a distinct
  traversal after formatting. _Rejected:_ duplicate formatted root imports.

## Referenced by

[[Type Interface Spec]] · [[src/test-fixtures/listeneridentity/Reverse]]
