---
type: module
path: "@root/lib/Std/Db.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, database]
aliases: [Std Db]
---
# Std Db
## Purpose
Ask a PostgreSQL database questions over a session, and hold connections between them.
## Interface
Simple and bound execution, row and column access, transactions and savepoints, scoped transaction
and savepoint helpers that undo what failed, and bounded connection pools. Opening and closing a
connection belong to [[Std Db Session]], which callers import alongside this.
## Governance and algorithm
Values reach a statement as parameters rather than as text placed into it, so nothing a caller holds
can become part of the statement. A scoped transaction rolls back when what it wrapped failed,
because a connection returned with a transaction still open would hand the next caller a
half-finished one. Server errors keep the severity, code, and message the server gave. Pools bound
their connection count through [[Std Channel]].
## Grill Log
- **Q:** Call the API database-agnostic? **A:** No. _Rationale:_ its protocol, authentication, type
  OIDs, and transaction status are PostgreSQL contracts. _Rejected:_ SQL string interpolation;
  forgetting a failed transaction's rollback requirement.
- **Q:** Use the clock-seeded deterministic generator for SCRAM? **A:** No. _Rationale:_ security
  protocol nonces require an unpredictable source. _Rejected:_ clock entropy; silent fallback.
## Referenced by
[[src/Std/_MOC]] · [[Std Db Session]] · [[Std Db Protocol]] · [[Std Net]] · [[architecture/STDLIB]]
