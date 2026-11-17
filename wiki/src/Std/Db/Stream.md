---
type: module
path: "@root/lib/Std/Db/Stream.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, database, streaming, protocol]
aliases: [Std Db Stream]
---
# Std Db Stream
## Purpose
Read the rows of one statement in bounded batches, so a large result never sits in memory whole.
## Interface
`stream(connection, sql, values, batch, each)` runs a statement and hands its rows to `each` in
batches of at most `batch` rows. The stream holds no more than one batch at a time. A batch smaller
than one row is refused before anything is sent. The command tag is answered together with the
connection.
## Governance and algorithm
The statement is sent as Parse, Bind, Describe for the portal, Execute with a row limit, and Flush.
The server sends at most `batch` rows and then suspends the portal (`PortalSuspended`). The stream
passes that batch to `each`, then sends Execute and Flush again to fetch the next batch. When the
server reports command completion (`CommandComplete`), the remaining rows are delivered, a Sync is
sent, the stream waits until the connection reports ready, and the command tag is returned with the
connection.

Values travel as parameters, as they do for every other statement in [[Std Db]], so no caller value
becomes part of the SQL text.

**A batch is read on an open portal.** Between batches the stream sends Flush, which asks the server
to deliver what it has produced and keeps the portal and any open transaction. Sync is reserved for
the end, because Sync closes the portal and would end the read after the first batch.

**A failed handler or server error is settled with a Sync.** When `each` returns an error, the stream
stops, sends Sync to close the portal, and returns the handler's error. A server error takes the same
path and is reported with the severity, code, and message the server gave. In both cases the
connection is left at ready, so the next statement reads its own answer and the connection can be
returned to a pool.
## Grill Log
- **Q:** Read each batch with Sync between batches? **A:** No. _Rationale:_ Sync closes the portal, so
  the second batch would have nothing to continue. Flush delivers the pending rows and leaves the
  portal open. _Rejected:_ one Sync per batch; reading the whole result into one array.
- **Q:** Leave the connection mid-read when a handler or the server fails? **A:** No. A Sync is sent so
  the next statement reads its own answer and does not inherit a suspended portal. _Rationale:_ a
  connection returned with an unfinished portal would hand the next borrower another statement's rows.
  _Rejected:_ closing the connection on every failure, which would discard a healthy connection.
- **Q:** Accept a batch of zero or fewer rows? **A:** No. A zero-row limit means the server never
  suspends, so the loop cannot progress. The stream refuses it before sending anything.
## Referenced by
[[src/Std/_MOC]] · [[Std Db]] · [[Std Db Protocol]] · [[Std Db Store]]
