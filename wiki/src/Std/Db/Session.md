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
before body accumulation. An incomplete header requests only its missing bytes. Once a complete
header has passed the budget check, the reader may take up to 64 KiB within the remaining buffer
budget, including following frames. Complete buffered frames require no transport call; following
bytes remain in the returned connection. Fragmented input obeys the same rules.
Incomplete frames accumulate byte segments and join once on completion, so a fragmented large
body does not repeatedly copy its growing prefix. Header admission precedes that accumulation.

Malformed framing, oversized frames, read failures, and EOF terminate this read and close the socket.
A close failure is included with the primary error rather than silently replacing it. An invalid
local size limit is rejected before touching the connection. This is a byte budget, not a deadline;
whole-query deadlines and aggregate row budgets remain separate work.

## Opening has a time limit

`Config.connectMillis` bounds opening a connection from dialling through the end of authentication:
`connect` dials with `Net.connectWithin`, and every read until the server reports it is ready waits
only for the time that remains. A host that drops packets and a server that accepts and then says
nothing are each refused with `Connect("the database did not finish opening the connection within
its time limit")`. The limit lives on the connection as a deadline that `connect` clears once the
connection is ready, so a query that legitimately runs long is never cut short; bounding a query is
the server's `statement_timeout`. `config` defaults the limit to `DEFAULT_CONNECT_MILLISECONDS`, ten
seconds. Against a local server that accepted and stayed silent, a 400 ms limit refused the
connection after 403 ms.

- **Q:** Put the same deadline on every read? **A:** No. _Rationale:_ a report or a migration that
  runs longer than any fixed limit is still correct, and cutting it off leaves work half done;
  PostgreSQL's `statement_timeout` is where a query's bound belongs. _Rejected:_ a default query read
  timeout.

### Resolved Grill Log

- **Q:** Buffer an arbitrarily large advertised frame? **A:** No; reject from the header before
  body allocation. Applications may explicitly select a larger budget.
- **Q:** Return a partially consumed connection after failure? **A:** No; this API returns no
  successor on failure, so the unusable transport is closed instead of leaking it.
- **Q:** Coalesce reads before validating the header? **A:** No; validate the advertised frame
  first. Read-ahead then stays within the existing buffer byte budget and chunk cap.
- **Q:** Concatenate the growing body after every fragment? **A:** No; retain segments and join once.

## Referenced by
[[src/Std/_MOC]] · [[Std Db]] · [[Std Db Protocol]] · [[Std Net]]

## Bounded pool admission (#468)

`DbError` adds `AdmissionTimedOut` for pool capacity expiry. It is distinct from a closed pool, expired lending, opening failure and command failure. Connection opening and message reading do not manufacture this cause. Existing exhaustive matches over this public sum must add the new case.

Resolved Grill Log: a pool wait is a typed cause rather than a message-text convention. This additive public variant requires independent contract review.
