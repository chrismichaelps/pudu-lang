---
type: architecture
status: ACTIVE
tags: [application, database, performance, layers]
aliases: [Application Maturity]
---
# Application Maturity

Pudu applications compose typed resources, configuration, routes, middleware and lifecycle stages.
Dependencies are parameters. Resource acquisition is explicit, and expected failures remain values.
The existing framework is the foundation; maturity requires executable evidence at its boundaries.

## Audit and delivery order

| Boundary | Existing foundation | Required evidence or correction |
| --- | --- | --- |
| Database transactions | One connection per action | Revoke retained callbacks and serialize commands before settlement. |
| Database throughput | Parameter binding and connection reuse | Measure frame reads, preparation, decoding and result allocation independently. |
| Dependency layers | Explicit imports | Reject cycles, missing modules and upward imports over the application dependency closure. |
| Dependency composition | Typed parameters and closures | Keep construction explicit; validate resource ordering before acquisition. |
| Routing and middleware | Route values and composed handlers | Cover ambiguity, refusal paths, middleware order and concurrency. |
| Configuration | Declared settings and layered overrides | Validate settings before resource acquisition; retain precise failures. |
| Lifecycle and hosting | Ordered start and reverse stop | Cover repeated transitions, failed startup, cleanup and draining under load. |
| Error handling | Typed failures and response helpers | Preserve causes while redacting client-facing operational details. |
| Observability | Health, measurements and traces | Prove concurrent updates and bounded cardinality. |
| Hot Reload | Watched process restart and generation | Refresh browsers after saved changes; keep ordinary hosting free of reload endpoints. |

Additional Pudu packages may support internal logging, message dispatch or resilience. Their
configuration and types stay behind framework-owned APIs; application authors use the Pudu App
surface. Existing locally available packages are audited before introducing a dependency.

## Transaction scope

An action receives a guarded transaction. Query and execute share one mutex and a live-state cell.
Each operation checks admission while holding the mutex and holds it through the complete command.
After the action returns, revocation takes the same mutex, waits for any admitted command, and
closes admission before the driver commits or rolls back. Saved handles answer category `expired`
without invoking a backend callback. Ordinary command and action failures retain their structured
values. A synchronization failure during revocation is reported alongside the original failure.

Public transaction entry and bundled callback entry both enforce this boundary. Custom connectors
should use the same scope helper when exposing their callback directly. Runtime abort, forced
cancellation, nested client calls and indefinitely running commands require separate cleanup and
deadline work; this guard does not establish those guarantees.

## Resolved Grill Log

- **Q:** Add a global dependency registry? **A:** No; dependencies remain typed parameters.
- **Q:** Revoke only successful actions? **A:** No; both typed outcomes end the scope.
- **Q:** Check admission outside the command lock? **A:** No; settlement could otherwise race a command.
- **Q:** Call this production-ready after focused tests? **A:** No; maturity follows complete boundary,
  load, failure, portability and independent review evidence.

## Combined validation boundary

The local validation branch combines transaction admission, bounded database read-ahead,
dependency enforcement, watched page refresh, concurrent request measurements and request
resource disposal. The constituent changes were separate drafts when assembled. The maintainer subsequently
requested merging completed requests into development in creation order. Combined build, full
suite, formatting, dependency gates and the packed retention workload pass. Independent review
has not occurred; these checks establish compatibility evidence, not production readiness.

Scoped savepoint cleanup now releases completed marks and preserves cleanup failures; the exact
protocol regression and its removal control establish bounded mark depth under repeated failures.
The audit still identifies callback abort cleanup, database admission
deadlines, aggregate result budgets and server shutdown ownership as unresolved boundaries.
Bounded channel receiving supplies an atomic wait foundation with distinct delivery, closure and
expiry outcomes. Database consumers adopt it through [[Database Admission Delivery]]; validation and review are required before that admission bound is claimed.
The server head reader also returns surplus bytes that request parsing currently discards;
coalesced requests require a focused transport regression before a repair is claimed.
Existing feature availability and passing fixtures do not establish production readiness.

## Referenced by

[[architecture/_MOC]] · [[Std App]] · [[Std App Database]] · [[Std Db Driver]] · [[2026-10-07-app-maturity]]
