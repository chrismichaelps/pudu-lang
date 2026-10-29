---
type: module
path: "@root/test-fixtures/ark/UsesArkSchedule.pudu"
fidelity: Active
aliases: [Ark Schedule Fixture]
tags: [module, ark, test]
---
# Ark Schedule Fixture

Checks [[Ark Schedule]] stage packing (readers share a stage, write conflicts follow declaration
order, `after` overrides declaration order, explicit chains are transitive, empty schedules);
refusals for empty and duplicate names, unknown access and filter components, unknown
dependencies, cycles naming only the unordered systems and self-dependency; a worker count of
zero; one-worker and four-worker runs equal to running the systems one by one with
`World.each`, with two writers of one archetype in a stage keeping both writes; `none` filters;
an undeclared read failing as `SystemFailed` with the archetype, and a write to a read-only
component never published. Prints `ark schedule: ok`.

## Referenced by

[[Ark World Gate]] · [[Ark Schedule]]
