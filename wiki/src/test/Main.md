---
type: module
path: "@root/test/Main.hs"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
grammar: "[[grammar/haskell]]"
tags: [module, test, runner]
aliases: [Repository Test Runner]
---

# Repository Test Runner

## Purpose and interface

Runs every registered QuickCheck property family with a visible label and fails the process if any
family fails. Output is line-buffered so a stalled property remains identifiable in captured logs.

## Governance and algorithm

Each spec exports named properties. The runner executes 200 cases per property, gathers every result
rather than failing early, and exits unsuccessfully when any result failed. Registration here and in
[[Pudu Test Cabal Manifest]] are both mandatory: one makes a property execute and the other makes
its module compile in the suite.

Lint analysis and command properties are separate families: [[Pudu Lint Spec]] proves pure typed
analysis, while [[Pudu CLI Lint Spec]] proves filesystem, configuration, JSON, and fix boundaries.

## Grill Log

- **Q:** Stop at the first failure? **A:** No. _Rationale:_ independent compiler phases can report
  useful failures in one run. _Rejected:_ fail-fast repository testing.
- **Q:** Discover Haskell specs dynamically? **A:** No. _Rationale:_ static registration lets GHC
  type-check the complete suite and makes omissions reviewable. _Rejected:_ filesystem reflection.

Resolved Grill Log: explicit dual registration and aggregate exit status make every property family
observable to CI.

## Referenced by

[[Pudu Test Cabal Manifest]] · [[architecture/DELIVERY]]
