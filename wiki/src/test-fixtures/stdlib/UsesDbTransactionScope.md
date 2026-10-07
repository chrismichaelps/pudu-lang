---
type: module
path: "@root/test-fixtures/stdlib/UsesDbTransactionScope.pudu"
fidelity: Active
tags: [test, database, concurrency]
aliases: [Uses Database Transaction Scope]
---
# Uses Database Transaction Scope

## Purpose and interface

A Pudu fixture with exact assertions over the public transaction boundary. It exits zero only
when every assertion holds; an assertion failure names its boundary.

## Algorithm and coverage

An explicit client records backend invocations and captures its transaction. Successful queries
and executions retain values. An action failure retains its full driver, category, code and message.
Saved handles after success and failure are refused as `expired`, including direct field callbacks,
and the backend invocation count cannot change. Concurrent query and execute callbacks track active
commands while yielding; their peak must be one and all commands must finish.

## Resolved Grill Log

- **Q:** Count assertions without comparing exact results? **A:** No; assert results and counters.
- **Q:** Require a live remote database for the scope test? **A:** No; the client seam isolates
  admission from transport. Real adapter transaction coverage is a separate gate.

## Referenced by

[[src/_MOC]] · [[Std Db Driver]] · [[Application Maturity]]
