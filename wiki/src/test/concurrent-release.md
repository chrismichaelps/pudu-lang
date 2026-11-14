---
type: module
path: "@root/test/concurrent-release.mjs"
fidelity: Active
aliases: [Concurrent Release Gate]
tags: [module, test, concurrency, memory]
---
# Concurrent Release Gate

## Purpose and algorithm

For each path of [[Concurrent Release Fixture]] (`ok`, `fail`, `parallel`), run it at 500 and at
5,000 rounds with `+RTS -t --machine-readable` and read `max_live_bytes`. Require the larger run
to hold less than twice the smaller one plus 4 MB. Before the fix the `ok` path held 191 MB at
2,000 rounds and 2.3 GB at 20,000, so a leak of even a few hundred bytes per round fails.

## Resolved Grill Log

- **Q:** Inspect the runtime's store size directly? **A:** No; nothing exposes it, and live
  bytes catch every retained structure, including thread stacks a forgotten record would keep.

## Referenced by

[[Repository Gates]] · [[Std Concurrent]]
