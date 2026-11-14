---
type: module
path: "@root/test/Pudu/Backend/TargetSpec.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, test, backend, mobile]
aliases: [Backend Native Target Tests]
---

# Backend Native Target Tests

## Purpose and interface

`backendTargetProperties :: [(String, IO Property)]` holds
[[Native Mobile Targets]] to its contract. The pure target policy runs without a platform SDK.

## Algorithm and invariants

- Target names are exactly the four documented, each found by its own name;
  runtime-pack names and partial names are not targets.
- System and embedded framework paths are accepted on iOS. Reject outside
  paths, parent traversal, slash-bearing versions and Android paths.

## Resolved Grill Log

Test path admission without contacting any SDK or dynamic loader.

## Referenced by

[[Backend Native Target]] · [[Repository Test Runner]]
