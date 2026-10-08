---
type: module
path: "@root/test-fixtures/dbwait/Main.pudu"
fidelity: Active
tags: [test, database, admission, concurrency]
aliases: [Database Admission Fixture]
---
# Database Admission Fixture

## Purpose and interface

Exact-zero Pudu regression over the shipped pool borrow and configured connector. Capacity waiting uses actual runtime channels and workers; a source-local transport controls connection bytes.

## Coverage and ownership

Prove zero and finite expiry, invalid wait refusal before dequeue, no callback or reopening on expiry, repeated timeout conservation, an admitted empty replacement slot, default finite waiting, ready-value delivery, exclusive concurrent borrowers and closure waking waiters. Callback closure and returned-slot paths retain existing results. Configured connector queries, execution and transaction admission use the selected limit and preserve the typed driver's expiry category.

Watchdog result channels bound fixture observation. Every worker is released by pool closure or an explicit gate, then joined and forgotten before failure is asserted. A deliberately altered wait must fail while retiring the worker. The initial baseline records a still-waiting borrower and uses closure to release it.

## Resolved Grill Log

- **Q:** Assert elapsed milliseconds exactly? **A:** No; distinguish typed outcomes, callback counts and conserved slots with generous observation bounds.
- **Q:** Leave the stalled control's worker alive? **A:** No; close admission and join before reporting failure.
- **Q:** Call controlled transport a live database conformance test? **A:** No; it isolates admission and exact protocol output.

## Referenced by

[[Protocol Evaluation Spec]] · [[Database Admission Delivery]] · [[Std Db Admission]] · [[src/_MOC]]
