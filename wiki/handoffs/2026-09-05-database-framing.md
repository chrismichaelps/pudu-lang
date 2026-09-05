---
type: handoff
status: IMPLEMENTED_UNVALIDATED
date: 2026-09-05
issue: 193
tags: [handoff, stdlib, database]
---

# Database Frame and Row Integrity

## Role transition and ownership

Language Architect → Standard Library Implementer. Own only `lib/Std/Db/Protocol.pudu`,
`lib/Std/Db/Session.pudu`, their mirrors, and this handoff for the first slice. FFI work currently
present in the shared tree belongs to other work and must remain unstaged. The user directs code
and documentation to `dev` and explicitly excludes tests and reviews for this feature.

## Resolved behavior

A PostgreSQL message length includes its four-byte length word and must be at least four. A short
header is incomplete; an invalid length is malformed. Only an incomplete frame causes another
socket read. The default session message budget is 16 MiB including tag and length; callers needing
a different cap use `nextMessageLimited`. Invalid budgets and oversized advertised messages are
refused before reading their body. Transport/framing failure closes the unusable socket and retains
the primary reason, with any close failure included in the returned error.

A text row's SQL NULL is exactly the all-ones length word. A zero length is empty text. Short field
payloads and invalid UTF-8 are protocol failures, never NULL. Row and row-description readers must
consume their complete payloads. This client requests text format and refuses binary columns.

## External contract

[PostgreSQL message formats](https://www.postgresql.org/docs/current/protocol-message-formats.html)
define the length words, row field lengths, NULL sentinel, and row-description format codes.

## Pool continuation ownership

Standard Library Implementer additionally owns `lib/Std/Db.pudu` and [[Std Db]] for positive pool
sizes, partial-construction cleanup, closing-state admission, failed settlement, and checked returns.
The shared FFI implementation remains outside this ownership boundary.

## Exact next action

Implement a real SQLite adapter against the backend-neutral driver contract; retain PostgreSQL SSLRequest/TLS upgrade as the next network transport gap.

## Implemented pool and query continuation

Positive pool sizes are required; construction failures drain partial resources. Closing state gates
borrow admission, and failed settlement closes the pool rather than circulating a broken connection.
Typed return/close failures are retained. Server query failures drain through ReadyForQuery; malformed
rows close the stream, and single-result collection refuses mixed command results.

## Validation

No tests, build, benchmarks, or code review are authorized for this pass. Implementation status is
not conformance evidence or a production-readiness verdict.

## Referenced by

[[handoffs/_MOC]] · [[Std Db Protocol]] · [[Std Db Session]] · [[CHANGELOG]]

## Application continuation ownership

Standard Library Implementer owns `lib/Std/App.pudu` and its mirror for lifecycle failure reporting.

Own new `lib/Std/Db/ConnectionString.pudu`, `lib/Std/App/Database.pudu` and their mirrors for the user-requested connection-string and application database integration.

## Implemented application continuation

Detailed lifecycle reports preserve all typed cleanup failures. URI parsing, direct session/pool opening, and application database stages now compose the existing real PostgreSQL query protocol. No live database was contacted and no tests/build/reviews were run.

Own `lib/Std/Db/Driver.pudu`, `lib/Std/Db/Postgres.pudu` and their mirrors for the user-directed backend-neutral driver boundary.
