---
type: module
path: "@root/test-fixtures/ark/UsesArkWorld.pudu"
fidelity: Active
aliases: [Ark World Fixture]
tags: [module, ark, test]
---
# Ark World Fixture

Checks [[Ark Handle]] generations and stale refusal; [[Ark World]] schema clashes, values in
caller order, count/unknown/duplicate refusals, tags, a lane system that moves only matching
archetypes, query exclusion, set, insert and remove keeping values and handles, swap-removal
keeping the moved row addressable, stale destroys; batched creation, compacting removal that
keeps order; [[Ark World Commands]] grouping, invalid creations answering `None` and queued
removal; [[Ark Profile]] statistics. Prints `ark world: ok`.

## Referenced by

[[Ark World Gate]]
