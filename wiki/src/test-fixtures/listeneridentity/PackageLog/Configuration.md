---
type: module
path: "@root/test-fixtures/listeneridentity/PackageLog/Configuration.pudu"
fidelity: Active
grammar: "[[grammar/pudu]]"
tags: [module, test]
---

# Listener Identity PackageLog/Configuration

## Purpose

Expose a configuration factory whose field carries the imported Listener alias.

## Contract

Main and Reverse check without diagnostics and return 0. The wrong Listener reports E3001.

## Grill Log

- **Q:** Is a synthetic Net replacement adequate? **A:** No; this graph loads the actual Std.Http.Server and Std.Net while a package-shaped module exports the conflicting alias.

## Referenced by

[[Type Interface Spec]]
