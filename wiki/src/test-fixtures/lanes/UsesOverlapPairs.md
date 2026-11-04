---
type: module
path: "@root/test-fixtures/lanes/UsesOverlapPairs.pudu"
fidelity: Active
aliases: [Overlap Pairs Fixture]
tags: [module, test, physics]
---
# Overlap Pairs Fixture

Compares [[Runtime Broadphase]] with a brute-force all-pairs reference on 200 pseudo-random
boxes; checks touching, nested and separate boxes, no boxes, and refusals for mismatched counts,
inverted bounds and NaN; then times 10,000 boxes. Run by [[Lanes Gate]].

## Referenced by

[[Lanes Gate]]
