---
type: module
path: "@root/test-fixtures/lanes/UsesLanes.pudu"
fidelity: Active
aliases: [Lanes Fixture]
tags: [module, test, lanes]
---
# Lanes Fixture

Golden values for every [[Std Lanes]] operation: construction refusals, get/set/slice bounds,
set leaving its input unchanged, elementwise arithmetic with signed zeros, mismatch refusals,
NaN-skipping extremes, gather/scatter ordering and refusals, the affine kernel and the
partial-value refusal of `fromBytes`; select with NaN masks, threshold masks, positions,
accumulating scatter-add and its refusals, and integer conversion with its refusals. Prints `lanes: ok`.

## Referenced by

[[Lanes Gate]]
