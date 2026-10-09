---
type: module
path: "@root/test/Pudu/Eval/MutexSpec.hs"
fidelity: Active
tags: [module, test, synchronization]
aliases: [Mutex Admission Spec]
---
# Mutex Admission Spec

Controlled competing owners prove zero/positive waits, eventual acquisition, self-reentry, disposal races, integer bounds, owner-only release, interruption/timer retirement and eight-borrower exclusion. Exact effect/type/arity refusals are checked; the real fixture executes in both evaluators with diagnostics retained. No portable timing guarantee. Requires [[Eval Concurrent]], [[Std Sync]] and [[Mutex Admission Fixture]].

Resolved Grill Log (#476): controlled admission and observed state prove ownership, with external deadlines preventing a regression from hanging the suite. Register explicitly in [[Repository Test Runner]] and [[src/pudu-tests-cabal|Pudu Test Manifest]].

## Referenced by
[[Database Mutex Delivery]] · [[src/Pudu/Eval/_MOC]] · [[src/_MOC]]
