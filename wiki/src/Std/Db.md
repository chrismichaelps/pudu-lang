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
Provide a typed PostgreSQL client with parameter binding, authentication, transactions, and pooling.
## Interface
Exports configuration/connect/close, simple and bound execution, row/column access, transaction and
savepoint operations, scoped transaction helpers, and bounded connection pools.
## Governance and algorithm
The connection carries unread bytes and server transaction status forward. Server errors retain
severity/code/message; SCRAM proves both peers; failed scoped transactions roll back; pools bound
their connection count through [[Std Channel]]. SCRAM client nonces come from [[Std Random]]'s
operating-system entropy boundary; authentication fails closed if entropy is unavailable.
## Grill Log
- **Q:** Call the API database-agnostic? **A:** No. _Rationale:_ its protocol, authentication, type
  OIDs, and transaction status are PostgreSQL contracts. _Rejected:_ SQL string interpolation;
  forgetting a failed transaction's rollback requirement.
- **Q:** Use the clock-seeded deterministic generator for SCRAM? **A:** No. _Rationale:_ security
  protocol nonces require an unpredictable source. _Rejected:_ clock entropy; silent fallback.
## Referenced by
[[src/Std/_MOC]] · [[Std Db Protocol]] · [[Std Net]] · [[architecture/STDLIB]]
