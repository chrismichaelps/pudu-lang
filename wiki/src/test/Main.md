---
type: module
path: "@root/test/Main.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[architecture/DELIVERY]]"
grammar: "[[grammar/haskell]]"
tags: [module, test, runner]
aliases: [Repository Test Runner]
---

# Repository Test Runner

## Purpose and interface

Runs every registered QuickCheck property family with a visible label and fails the process if any
family fails. Output is line-buffered so a stalled property remains identifiable in captured logs.

Registers [[Derive Library Spec]].

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
- **Q:** Run the library fixtures separately? **A:** No; with every other derive family.

## Referenced by

[[Pudu Test Cabal Manifest]] · [[architecture/DELIVERY]]

Reflection Resolution Spec is registered beside ordinary resolution properties,
covering selected and first-class metadata imports, namespace shadowing and
repeated rigid loop bounds. Resolved Grill Log: explicit registration makes
these boundary tests execute in the full suite.

[[Generated Identity Spec]] is registered explicitly. Resolved Grill Log: source,
checker and persistence identity regressions execute in the full suite.

[[Derive Record Kernel Spec]] is registered explicitly and exercises generated ordinary
implementations in both evaluator modes. Resolved Grill Log: actual expansion output
is checked, with graph publication retained as a distinct integration gate.

Register [[Type Implementation Proof Spec]] with ordinary type properties.
Resolved Grill Log: full conditional capability evidence runs in the complete suite.

The runner explicitly executes [[Type Literal Frontier Spec]] and includes its
outcomes in the aggregate exit status. Resolved Grill Log: an unregistered
performance regression property does not count as validation.

Register [[Derive Catalogue Spec]] beside the residual kernel families and include
its results in aggregate exit status. Resolved Grill Log: canonical inventory
tests execute without being mistaken for loaded-program generation evidence.

Register [[Derive Requirement Spec]] alongside canonical catalogue families;
aggregate every result. Resolved Grill Log: isolated inference regressions are
visible independently of successful concrete generated methods.

Register [[Derive Target Spec]] and aggregate its preparation, round-trip and
refusal outcomes. Resolved Grill Log: concrete aliases do not escape validation.

Register [[Derive Cache Spec]] and aggregate every outcome. Resolved Grill Log:
cache-key tests accompany actual warm consumer execution after helper edits.

Register [[Derive Graph Spec]] independently of kernel transformations and include
its real loaded-program successes/refusals in aggregate exit status.

Registers [[Lsp Impl Members Spec]] with the language-server properties.

## Qualified shadow registration (#471)

Register Qualified Shadow Spec beside resolution checks and aggregate every result. Resolved Grill Log: focused and complete runs execute the same lexical, loaded, diagnostic and evaluator regressions.
