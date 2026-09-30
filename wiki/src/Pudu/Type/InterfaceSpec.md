---
type: module
path: "@root/test/Pudu/Type/InterfaceSpec.hs"
fidelity: Active
tags: [module, test]
aliases: [Type Interface Spec]
---

# Type Interface Spec

## Purpose

Verify body-free export projection, private shells, selective imports, trait defaults, and
declaration-order-independent transparent alias formation across module boundaries.

## Interface

`interfaceProperties :: [(String, IO Property)]`

## Governance

The late-alias regression compiles and runs an importing module whose record field names a later
function alias through a later generic alias. A mismatched callback must retain `E3001`.

The Listener collision regression loads the actual HTTP server and a package-shaped module with
a function alias called Listener. Both dependency traversal orders check and run; a Net.Listener record
still fails when passed where the callback alias is required.

## Grill Log

- **Q:** Is successful formation alone enough? **A:** No; assert exact imported checking and
  runtime output, plus rejection of a callback with a different parameter type.

## Linkage

- **Requires:** [[Type Interface]], [[Type Interface Graph]], [[Type Formation]].
- **Consumed by:** [[src/_MOC]].

## Referenced by

[[src/Pudu/Type/_MOC]]
