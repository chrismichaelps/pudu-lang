---
type: module
path: "@root/test-fixtures/stdlib/ReleasesConcurrent.pudu"
fidelity: Active
aliases: [Concurrent Release Fixture]
tags: [module, test, concurrency]
---
# Concurrent Release Fixture

Runs a number of rounds given as its last argument; the argument before it selects the path.
`ok` maps four items with `mapBounded` on four workers and checks the order-preserving result;
`fail` maps items whose transform panics on one, requiring a `Failed` result every round;
`parallel` runs four actions through `parallel`. Prints `rounds <n>` when done. Live memory must
not grow with the round count on any path.

## Referenced by

[[Concurrent Release Gate]] · [[Std Concurrent]]
