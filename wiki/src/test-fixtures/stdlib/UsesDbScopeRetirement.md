---
type: module
path: "@root/test-fixtures/stdlib/UsesDbScopeRetirement.pudu"
fidelity: Active
tags: [test, database, lifetime]
aliases: [Database Scope Retirement Fixture]
---
# Database Scope Retirement Fixture

Exercise closeMutex success, Missing and self-owned refusal. Repeated successful and typed-failed Driver scopes preserve exact outcomes, save their guarded handles, and require query and execute to report expired without a backend call. Remove fixture-owned cells and counters before main finishes. The native property inspects its live registry before runtime teardown and requires zero remaining registrations.

Resolved Grill Log: repeated no-op transactions reveal guard accumulation independently of backend allocation; explicit fixture cleanup prevents unrelated counters from masking the scope lifetime assertion. Both ordinary entry and live-environment execution retain exact diagnostic/output evidence.

## Referenced by

[[Mutex Admission Spec]] · [[Std Db Driver]] · [[src/_MOC]]

Validation (#480): both real and confined entries pass in both evaluators. Carried and source-only bundles pass after source removal with no inherited environment. The native live-registry assertion reproduces 1,000 mutex/cell registrations each before Driver retirement and requires zero afterward.
