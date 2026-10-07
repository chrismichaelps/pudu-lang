---
type: handoff
status: ACTIVE
issue: 453
tags: [application, runtime, resources]
---
# Runtime Disposal Delivery

Language Architect resolves explicit disposal in [[Eval Concurrent]], [[Std Sync]] and
[[Std Concurrent]]. Runtime Engineer owns those boundaries, primitive registration and exact
resource tests. The same slice owns private task disposal in [[Std Concurrent]] containment and
request-holder disposal in [[Std Http Server]]. Work remains sequential; independent semantic and vault-parity review precedes
integration. Existing large registration modules receive only the matching primitive entries.
The existing server module exceeds the default size; this slice adds only private containment
cleanup. Splitting its hosting responsibilities is a separate architecture change.

The request containment probe retains 161366016 peak resident bytes at 1000 requests,
422445056 at 10000 and 1750728704 at 100000. These local measurements identify a lifetime problem,
not production capacity. Runtime tables currently retain every token until evaluation teardown.

Add explicit cell and unowned-mutex disposal and forgetting completed threads. Retirement precedes
registry removal, identifiers are never reused, and active resources are refused. Preserve replayable
joins until explicit forgetting. Register ordinary effect and confinement rules. Quiescent runtime
counts prove actual registry removal; typed fixtures prove public success and refusal.

The repaired probe reaches 138199040, 138231808 and 137527296 peak resident bytes at the same
counts; a second 100000-request run reaches 138149888. [[App Retention Probe]] preserves the
workload. Table-count and contention checks pass; removing actual cell-table deletion makes the
regression fail. Direct, packed and confined typed checks pass. Formatting, lint and warning-strict
build and final full suite pass. The repository probe with exact response-body assertions reaches
138264576 bytes at 100000 requests. Independent review has not occurred.

Exact next action: obtain independent semantic and vault-parity review of the focused disposal change.

## Referenced by

[[handoffs/_MOC]] · [[Eval Concurrent]]
