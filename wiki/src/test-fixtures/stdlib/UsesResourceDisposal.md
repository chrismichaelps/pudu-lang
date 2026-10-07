---
type: module
path: "@root/test-fixtures/stdlib/UsesResourceDisposal.pudu"
fidelity: Active
tags: [test, resources, concurrency]
aliases: [Uses Resource Disposal]
---
# Uses Resource Disposal

## Purpose and algorithm

Typed wrappers refuse repeated or unknown disposal, retire cells and locks, preserve live owners,
refuse forgetting active tasks and allow completed-task forgetting after repeatable joins.
Failed completed tasks retain their failure until forgetting; unknown task and lock tokens refuse
disposal through their typed Missing result.
Every assertion names its invariant and success is exactly zero through both evaluators.

## Resolved Grill Log

- **Q:** Hide an active thread by forgetting it? **A:** No; wait for its outcome first.
- **Q:** Discard a lock's owner? **A:** No; disposal requires an unowned lock.

## Referenced by

[[Std Sync]] · [[Std Concurrent]] · [[Protocol Evaluation Spec]] · [[src/_MOC]]
