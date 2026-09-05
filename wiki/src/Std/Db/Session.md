---
type: module
path: "@root/lib/Std/Db/Session.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, database, connection]
aliases: [Std Db Session]
---
# Std Db Session
## Purpose
Become a connection to a database, and carry one message across it at a time.
## Interface
Where a database is and who is asking; the connection and what it has read but not yet made a
message of; why an operation failed; what a transaction is currently doing; opening a connection,
reading the next message, writing bytes, reading the status a message reported, and closing.
## Governance and algorithm
Separated from [[Std Db]] because the two answer different questions: this one knows how to become a
connection and how to read one message, that one knows what a query is, what a transaction
promises, and how a pool hands a connection round. Authentication is where a mistake is quietest, so
it is read without row access around it. A failure the server reported is kept apart from every
other kind and carries the server's own code, because a caller retries a unique-key violation
differently from a syntax error and matching on message text breaks when the server is translated or
upgraded. The status byte the server sends with every ready message is the only thing believed about
whether a transaction is open.
## Grill Log
- **Q:** Track transaction state locally? **A:** No. _Rationale:_ the server sends it with every
  ready message, and a local copy can disagree. _Rejected:_ counting begins and commits.
- **Q:** Take a nonce from the deterministic generator? **A:** No. _Rationale:_ a repeatable nonce
  is not a nonce. _Rejected:_ sharing [[Std Random]] with authentication.
## Bounded message admission

`nextMessage` uses a 16 MiB complete-message cap. `nextMessageLimited(stream, maxBytes)` accepts a
caller-selected cap of at least five bytes. The advertised size is checked once a header is present,
before body accumulation. Only the current frame's missing bytes are requested, capped at 64 KiB per
read; bytes already buffered for subsequent frames remain in the returned connection.

Malformed framing, oversized frames, read failures, and EOF terminate this read and close the socket.
A close failure is included with the primary error rather than silently replacing it. An invalid
local size limit is rejected before touching the connection. This is a byte budget, not a deadline;
whole-query deadlines and aggregate row budgets remain separate work.

### Resolved Grill Log

- **Q:** Buffer an arbitrarily large advertised frame? **A:** No; reject from the header before
  body allocation. Applications may explicitly select a larger budget.
- **Q:** Return a partially consumed connection after failure? **A:** No; this API returns no
  successor on failure, so the unusable transport is closed instead of leaking it.

## Referenced by
[[src/Std/_MOC]] · [[Std Db]] · [[Std Db Protocol]] · [[Std Net]]
