---
type: handoff
status: REVIEW_PENDING
issue: 480
aliases: [Database Scope Retirement Delivery]
tags: [database, lifetime, synchronization]
---
# Database Scope Retirement Delivery

Language Architect resolves joined retirement before implementation. Runtime Engineer owns Eval.Concurrent, builtin definitions, effect delegation, confinement and both prelude registrations. Standard Library Engineer owns Std.Sync and Std.Db.Driver. Test Engineer owns MutexSpec and UsesDbScopeRetirement. Forensic Guardian owns their complete mirrors, maps, maturity ledger and this handoff. Transitions follow that order, directly and sequentially on fresh feature/480-scope-retirement from fetched development c13dd93e. Preserve unrelated work and all existing runtime behavior. Complete owned mirrors and resolved Grill Logs precede source edits.

Each current scope leaves its mutex and live-state cell registered after either typed outcome. Close stops admission before joining an existing owner; an owner's closing release retires the registration even if the closer was interrupted. Keep ordinary owned disposal refusal and self-owned close refusal. Driver revokes first, then closes the gate and disposes the cell. Retired private gate acquisition preserves expired classification. Do not force-release or time out admitted commands.

Acceptance includes controlled owner/entrant/closer and closer-cancellation cases, zero quiescent counts, repeated actual scopes observed before runtime teardown, preserved outcomes and retained-handle refusals, exact effect/type/arity diagnostics, both evaluators, packaging, strict focused/full gates, library/API/format/lint/graphs, owned parity and private inputs. Runtime abort cleanup and backend-command deadlines remain separate. Independent approval is not claimed.

## Delivery evidence

The actual fixture before Driver retirement fails with 1,000 retained mutexes and 1,000 retained cells observed inside the live runtime. After retirement, both evaluator modes require zero counts before teardown. Across 1,000 alternating successful and typed-failed scopes per run, exact outcomes survive, admitted callbacks run exactly 2,000 times and every retained query/execute attempt remains expired.

Controlled native close cases pass 200 trials, including parked entrants, retained ownership, foreign-release refusal, interruption of the joining closer and zero counts. Exact constant-effect/type/arity refusals remain E7009/E3001/E3003. The final complete suite passes all 614 groups. The optimized strict build actually rebuilds all 284 production and 107 test components; the available local compiler is 9.10.3, with the supported 9.14.1 check pending remotely.

Both modes pass real entry and confined entry. All 217 library and 28 example sources check. Full Pudu formatting, typed CLI lint, scheduled API lifecycle and public API coverage pass: 4,007 exports, 3,649 covered, zero undocumented. Carried bundles contain eight products; the source-only stand-in contains zero. Both run in both modes after removing the source and named runtime, with no inherited environment and from an unrelated directory. The stand-in verifies bundle mechanics rather than another platform.

All 16 graph properties pass. The application graph covers 217 sources and 98 framework dependencies with zero findings; the compiler graph has 284 modules, 32 layers and zero cycles. The diagnostic consistency check reports 165 codes across 283 sources. Owned mirrors, links, maps, ignored private inputs, whitespace and review size are audited together. Existing closed-table size exceptions are 751 and 514 lines; lifecycle policy stays in the 441-line coordinator.

Runtime abort cleanup, admitted-command deadlines and backend-client retirement remain separate unresolved boundaries. No independent implementation, language or parity approval is claimed. Direct sequential work follows the user's instruction.

Exact next action: obtain independent implementation, public-contract and vault-parity review of issue #480 before merge; continue the Database callback-abort lifetime audit separately.

## Referenced by

[[handoffs/_MOC]] · [[Application Maturity]] · [[Mutex Admission Spec]] · [[Database Scope Retirement Fixture]]
