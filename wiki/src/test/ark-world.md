---
type: module
path: "@root/test/ark-world.mjs"
fidelity: Active
aliases: [Ark World Gate]
tags: [module, ark, test]
---
# Ark World Gate

Runs [[Ark World Fixture]], [[Ark Hierarchy Fixture]] and [[Ark Schedule Fixture]], checks
formatting of Core and World modules, [[Ark World Benchmark]] and [[Ark Schedule Benchmark]],
requires positioned type refusals for a World passed as a View and for a non-integer worker
count, and confirms the modules ship in the source distribution. `--bench` prints nanoseconds
per frame for both layouts and for one-worker and four-worker schedule runs. Registered in [[Pudu Continuous Verification]] with the Ark math gates.

## Referenced by

[[Ark World]] · [[Ark World Delivery]] · [[Ark Schedule]]
