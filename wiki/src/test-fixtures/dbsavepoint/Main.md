---
type: module
path: "@root/test-fixtures/dbsavepoint/Main.pudu"
fidelity: Active
tags: [test, database, lifecycle]
aliases: [Database Savepoint Fixture]
---
# Database Savepoint Fixture

## Purpose and interface

Run the shipped savepoint scope and session reader against [[Savepoint Fixture Transport]].
`main` returns zero only after every assertion executes; a mismatch stops with a named failure.

## Algorithm and coverage

Build ordinary session connections over the controlled transport. Check successful values,
exact original action errors, rollback followed by release, outer marks, nested same-name scopes
and quoted names. Repeat failed scopes inside one transaction and check that mark depth returns
to its starting value and peak depth remains bounded. Also refuse initial marks, rollback and
release independently; check skipped callbacks, exact error variants, cause order and absence
of commands after failed rollback. Direct and packed execution must agree.

## Resolved Grill Log

- **Q:** Count any positive result as success? **A:** No; every assertion is mandatory and the result is zero.
- **Q:** Only inspect whether an error occurred? **A:** No; compare error values and command order.
- **Q:** Measure retained scopes from helper state? **A:** No; the transport tracks its own mark stack.

## Referenced by

[[Std Db]] · [[Protocol Evaluation Spec]] · [[src/_MOC]]
