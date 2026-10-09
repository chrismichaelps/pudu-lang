---
type: module
path: "@root/test/derive-index.mjs"
fidelity: Active
subsystem: "[[Tooling]]"
tags: [test, derive, output]
aliases: [Derive Index Output Gate]
---
# Derive Index Output Gate

## Purpose and interface

Runs against a supplied built Pudu executable. Temporary modules exercise documentation and public API output for public Record and Sum strategies, private strategies, complete trait arguments and declaration comments. Standard library checks cover Show, Eq, Ord, Hash, Encode, Decode and Row.

## Invariants and failures

Parse actual command output and compare exact strategy metadata, signature, comment, source span, root visibility and existing ordinary export identity shape. Invalid input refuses public API output while documentation retains recoverable authored declarations. Temporary inputs are removed even after failure.

## Resolved Grill Log

- **Q:** Test only the index encoder? **A:** No; graph elaboration can discard declarations before encoding.
- **Q:** Treat strategies as ordinary symbol exports? **A:** No; verify additive metadata without introducing a binding or dependency re-export.

## Referenced by

[[Pudu Continuous Verification]] · [[Documentation Spec]] · [[src/Pudu/Doc/_MOC]] · [[src/_MOC]] · [[Derive Index Delivery]]
