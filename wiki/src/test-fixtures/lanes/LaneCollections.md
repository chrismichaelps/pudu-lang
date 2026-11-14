---
type: module
path: "@root/test-fixtures/lanes/LaneCollections.pudu"
fidelity: Active
aliases: [Lane Collection Fixture]
tags: [module, test, performance]
---
# Lane Collection Fixture

Runs four hundred lane kernel calls on one thread (two hundred `addScalar` and `sqrt` passes
over a 400,000-element ramp), each writing a fresh 3.2 MB buffer, and prints whether the final
sum is positive. Its collection count depends on the large-object allocation limit and not on
the number of capabilities, so [[Lane Collection Gate]] can assert it on any runner.

## Referenced by

[[Lane Collection Gate]]
