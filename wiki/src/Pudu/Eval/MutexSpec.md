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

## Joined scope retirement (#480)

Controlled closure checks retain an owner while a closer and entrants park, require refusal after closing, prohibit foreign release, and join owner release before asserting zero counts. Cancel a parked closer and require the owner release to remove its registration. Exact effect/type/arity refusals remain checked. Run the real Database retirement fixture in both evaluators and inspect counts inside its live runtime environment before teardown, including repeated success and failure scopes. Resolved Grill Log: whole-program cleanup cannot prove per-scope retirement; external test deadlines expose a stranded owner or waiter.

The self-owned close refusal also has an external test deadline. Resolved Grill Log: a recursive-close regression must fail visibly rather than strand the suite.
