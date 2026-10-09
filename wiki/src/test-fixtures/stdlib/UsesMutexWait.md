---
type: module
path: "@root/test-fixtures/stdlib/UsesMutexWait.pudu"
fidelity: Active
tags: [module, test, synchronization]
aliases: [Mutex Admission Fixture]
---
# Mutex Admission Fixture

Exercises public lock wrappers including Acquired(None), no callback on expiry, typed failure release and invalid waits. A real local transaction is held with channels; all four competing client operations expire without effects. Release restores usability, recursive client refusal rolls back, and configuration bounds are checked. Requires [[Std Sync]], [[Std Db Sqlite]] and [[Std Db Driver]].

Resolved Grill Log (#476): controlled admission and observed state prove ownership, with external deadlines preventing a regression from hanging the suite. Register explicitly in [[Repository Test Runner]] and [[src/pudu-tests-cabal|Pudu Test Manifest]].

## Referenced by
[[Database Mutex Delivery]] · [[src/Pudu/Eval/_MOC]] · [[src/_MOC]]
