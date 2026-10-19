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

Register [[CLI Memory Tests]] and [[Native Frame Runtime Tests]] with the backend
group. Resolved Grill Log (#499): host and allocator-failure checks run in the
complete suite and through focused filters with unchanged exit aggregation.

Register [[Native Frame Body Tests]] beside continuation lowering. Resolved
Grill Log (#499): strict generated-C checks execute in focused and full suites.

Register [[Native Frame Lowering Tests]] beside backend properties and aggregate
its outcomes. Resolved Grill Log (#499): focused and complete runs execute the
same continuation checks without claiming runtime frame repair.

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

Register [[Module Qualifier Spec]] beside resolution properties and include its outcomes in aggregate exit status. Resolved Grill Log: focused and full runs execute the same boundary properties.

## Qualified shadow registration (#471)

Register Qualified Shadow Spec beside resolution checks and aggregate every result. Resolved Grill Log: focused and complete runs execute the same lexical, loaded, diagnostic and evaluator regressions.

## Ordered integration (#471)

Register both Module Qualifier Spec and Qualified Shadow Spec in the same resolution result group. Resolved Grill Log: integrating earlier repairs retains both imports, both property collections, and aggregate failure propagation.

Register [[Mutex Admission Spec]] explicitly with existing dependencies. Resolved Grill Log (#476): the controlled native family and real public fixture run in the complete suite.

Register [[Database Challenge Spec]] explicitly with existing dependencies. Resolved Grill Log: complete-suite execution and focused execution use the same real challenge admission assertions.

## Native function and process regressions (#488)

Register [[Backend Function Programs]] as the native function corpus and [[Backend Toolchain Tests]] as an executed property family. Resolved Grill Log: the full suite must run independent differential and adversarial process regressions through static registration; no new test dependency.

## Native control flow (#489)

Register the loop-control lowering helper and native control-flow property/corpus modules through explicit module lists and the existing test aggregator. Resolved Grill Log: no new dependency or source discovery; focused and full suites execute the same control-flow evidence.

## Unit conditional conformance (#490)

Register [[Eval If Unit Tests]] explicitly and execute its property family alongside
ordinary evaluator checks. Resolved Grill Log: include unit-result, contextual
Dynamic, constant and actual boxed-kernel regressions in focused and full runs.

## Native solved facts (#491)

Register and run [[Native Solved Types Tests]] alongside backend properties. Resolved Grill Log: missing/colliding facts and canonical identity checks execute in the full suite.

## Portable wide-word prerequisite

Register and aggregate [[Native Word128 Tests]] beside native runtime properties.
Resolved Grill Log: actual strict C11 execution must validate the prerequisite without claiming typed emission admission.

## Exact wide values (#502)

Execute and aggregate [[Native Wide Value Tests]] beside the raw word kernel corpus.
Resolved Grill Log: helper-selection and exact-sign checks must execute without admitting source types early.

## Typed wide operation registration (#503)

Execute and aggregate [[Native Wide Operation Tests]] beside the wide value/raw word groups.
Resolved Grill Log: execute independent mathematical/refusal and minimal-closure evidence; source admission remains a later obligation.

## Wide runtime integration (#504)

Execute and aggregate [[Native Wide Runtime Tests]] beside wide primitive/value groups.
Resolved Grill Log: actual production runtime selection/output/failure evidence must execute before wide-frame/source admission.

## Closed-output regression (#505)

Execute and aggregate [[Native Broken Pipe Tests]] alongside native runtime conformance properties.
Resolved Grill Log: restore default SIGPIPE in a separate launcher so inherited evaluator policy cannot mask the native defect.

## Wide frame execution (#506)

Register and execute [[Native Wide Frame Tests]] with existing dependencies.
Resolved Grill Log: the actual Core/frame C11 corpus and cleanup checks run in
focused and complete suites; public source admission remains pending.
