---
type: handoff
status: REVIEW_PENDING
issue: 476
tags: [database, synchronization]
aliases: [Database Mutex Delivery]
---
# Database Mutex Delivery

Language Architect resolved typed finite admission before readiness. Runtime Engineer owns Eval.Concurrent, Eval.Effect, Eval.Confinement, Eval.Builtin.Definition, Semantic.Prelude, Type.Check.Prelude, Std.Sync and the local connector. Test Engineer owns MutexSpec, UsesMutexWait and runner/manifest registration. Complete mirrored contracts with resolved Grill Logs precede source edits. Work is direct and sequential on feature/476-bounded-mutex-admission from fetched development c2b436a8; preserve all other pushed work. Transitions: Language Architect → Runtime Engineer → Test Engineer. Independent implementation, public-boundary and vault-parity review remains required.

Success means atomic admission or distinct expiry, no action after expiry, no self-reentry deadlock and original ownership preserved. Local clients default to 10000 milliseconds; overrides admit zero through one hour before opening. All four outer operations share this policy. Do not cancel admitted commands or settle while scoped work still owns admission. Runtime abort/cancellation cleanup remains a cohesive follow-up, not a claim of this delivery.

Acceptance: controlled native owners and lifetime checks, exact refusals, real connector contention/recovery in both evaluators, packaged execution and removal control, fresh strict optimized build, focused/full gates, library/API/format/lint, dependency graphs and vault parity.

The fresh strict optimized production build compiled all 283 components; the first test build exposed an undeclared counter dependency. The counter now uses existing atomic storage, and all 103 test components plus runner link complete. The preliminary worker yielded rows instead of unit; discarding its transaction result resolves the inspected E3001. Both focused families pass, including exact E7009/E3001/E3003 refusals, timer interruption/retirement, retirement races and eight-borrower exclusion. Real local contention exercises all four outer operations at zero and positive waits; recursive refusal rolls back its write.

Two direct evaluator runs and six packaged runs pass after removing original sources, from an unrelated directory and empty environment. Carried delivery contains 18 products; a changed-digest source-only stand-in contains zero. Allowing an expired wait to invoke its action in a private wrapper copy makes both evaluators refuse with E7007 as expected. The actual confined command admits the new synchronization effect. This is local execution evidence, not another-platform validation.

All 605 complete-suite groups pass with zero failing groups, including the shared channel timer regression. All 243 shipped library/example sources check; formatting, command lint and diagnostic consistency pass. API coverage is 3635 of 3994 exports with zero undocumented exports. Five application-layer regressions pass; its graph contains 215 modules and 96 framework modules with zero findings. The native graph has 282 modules, 31 layers and no cycles or missing edges. Added vault links resolve; independent implementation, public-boundary and vault-parity review remains pending.

Exact next action: obtain independent implementation, public-boundary and vault-parity review of the draft #476 delivery before integration. The original application goal remains active; cohesive abort/cancellation recovery and retained transaction resource retirement remain Database audit gaps.

## Referenced by
[[handoffs/_MOC]] · [[Eval Concurrent]] · [[Std Sync]] · [[Std Db Sqlite]] · [[Mutex Admission Spec]] · [[Mutex Admission Fixture]]
