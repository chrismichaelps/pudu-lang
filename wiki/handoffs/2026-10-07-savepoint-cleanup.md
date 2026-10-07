---
type: handoff
status: ACTIVE
issue: 456
tags: [application, database, lifecycle]
---
# Savepoint Cleanup Delivery

Language Architect resolves scoped mark ownership in [[Std Db]] before implementation.
Runtime Engineer owns `withSavepoint`, [[Database Savepoint Fixture]], [[Savepoint Fixture Transport]],
the fixture registration and their matching vault pages. Work is sequential; preserve other work.
The branch starts from fetched development commit `55f4f9f53ad32ee7ca501fbd0b53d8de5bf45844`.

The existing database module exceeds the default file size. This repair changes only the private
cleanup flow of one existing helper and adds no public signature or dependency. Splitting command,
pool and transaction responsibilities requires a separately resolved layer contract.

Acceptance covers exact action outcomes, both cleanup refusals, skipped callback after initial
mark refusal, nested marks, duplicate and quoted names, repeated depth restoration, direct and
packed execution, formatting, lint, focused and full compatibility, dependency gates and vault
parity. Removing release after rollback must reproduce retained mark depth. No cancellation,
whole-transaction cleanup, admission deadline or production capacity guarantee is added.

The original helper retains 1000 completed marks across 1000 failed actions. The repaired helper
retains zero, with peak depth one. The direct and packed fixtures pass; skipping release after
rollback restores all 1000 retained marks and fails the named assertion. The production helper
was restored before final validation. Exact cleanup refusals, original causes and command order
pass. Formatting, lint, warning-strict optimized build and full suite pass. Fourteen graph tests
pass; the source graph has 215 modules and 96 framework dependencies with no findings.

The controlled transport validates cleanup ownership and protocol sequencing. No fresh external
database execution, cancellation or production-load measurement is claimed by this slice.
Independent implementation and vault-parity review have not occurred.

Exact next action: publish the validated savepoint cleanup for independent review.

## Referenced by

[[handoffs/_MOC]] · [[Std Db]] · [[Application Maturity]]
