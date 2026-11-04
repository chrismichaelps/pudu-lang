---
type: module
path: "@root/test/lane-collections.mjs"
fidelity: Active
aliases: [Lane Collection Gate]
tags: [module, test, performance, concurrency]
---
# Lane Collection Gate

## Purpose and algorithm

Run [[Lane Collection Fixture]] with the supplied compiler and `+RTS -t --machine-readable`,
read `num_GCs` from the statistics the runtime prints, and require fewer than 100 collections for
its 400 lane kernel calls (37 with the linked limit, 202 without), under the same bound at one and
two capabilities. Then run [[Lane Parallel Benchmark]] for its output shape and check both
files' formatting. Without a large-object allocation limit above the nursery, nearly
every kernel call triggers a stop-the-world collection that waits for every other thread's
kernel loop, so lane work on several threads takes turns instead of overlapping. Counting
collections is deterministic where a timing comparison on a shared CI runner is not. The two
worker counts in the benchmark must also agree on every result.

## Resolved Grill Log

- **Q:** Assert a parallel speedup? **A:** No; CI runners have few, shared cores, so a ratio
  flakes. The collection count is the mechanism the speedup depends on and does not vary.

## Referenced by

[[Repository Gates]] · [[Pudu Cabal]]
