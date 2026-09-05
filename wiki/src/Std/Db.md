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
## Pool resource lifecycle

A pool requires a positive size and owns a shared closing cell beside its channel. Construction
failure closes every successfully opened connection. A connection that cannot be queued during
construction is also closed. Cleanup failures are retained with the primary construction error.

Borrowers check closing state after acquisition, so queued connections cannot start new work after
closure is observed. Returning a connection validates transaction settlement; a failed rollback
closes that connection and closes the pool, waking waiters rather than silently shrinking capacity
until they wait forever. A connection returned after closure is closed by its borrower. Only successful callbacks and
synchronized server errors are candidates for reuse; other database failures close the pool because
this callback API cannot establish transport health. All typed
return, settlement, and close failures are propagated instead of being discarded.

`closePool` closes admission and the queue, drains queued connections, and attempts all closes.
It does not wait for active callbacks; their returns perform final cleanup. Host panic and forced
worker cancellation are not handled by this pure-Pudu scoped helper and remain runtime work.

### Resolved Grill Log

- **Q:** Return an empty pool after requesting zero connections? **A:** No; refuse before allocating
  a channel. No caller can make progress through such a pool.
- **Q:** Put a failed rollback's connection back? **A:** No; it has unknown transaction state.
  Discard it and close admission rather than reusing it or stranding capacity waiters.
- **Q:** Lose earlier opens if a later connection fails? **A:** No; constructor failure owns all
  partial resources and drains them before returning its error.

## Query failure synchronization

A server ErrorResponse is retained separately from a fatal transport or parsing error. Collection
continues through ReadyForQuery before returning that server failure, so the next command cannot
mistake the previous command's ending for its own. A malformed row or transport failure closes the
connection. Data-row column counts must match their description. A single-result API refuses
multiple command results instead of mixing rows from different schemas.

### Resolved Grill Log

- **Q:** Stop at ErrorResponse although ReadyForQuery is still pending? **A:** No; retain the
  recoverable server error and drain the response boundary before returning it.
- **Q:** Combine several command results into one `Rows` value? **A:** No; a single schema cannot
  describe arbitrary multiple results. Multi-result execution needs a separate explicit API.

## Referenced by
[[src/Std/_MOC]] · [[Std Db Session]] · [[Std Db Protocol]] · [[Std Net]] · [[architecture/STDLIB]]

Connection URI opening is available through [[Std Db ConnectionString]]; [[Std App Database]] connects pool lifetime to application stages and provides parameterized queries for handlers.
