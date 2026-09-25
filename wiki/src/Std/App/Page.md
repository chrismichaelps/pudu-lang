---
type: module
path: "@root/lib/Std/App/Page.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, application, pagination, http]
aliases: [Std App Page]
---

# Std App Page

## Purpose and interface

Keyset (cursor) pagination: bounded page sizes, opaque cursors, and a `Link` header, so a listing
stays stable while rows are inserted and costs the same on page one thousand as on page one.

Exports:
- `type Request = { size, after }`, `type Page[T] = { items, next }`,
  `type PageError = SizeNotANumber(Str) | SizeOutOfRange(Int, Int) | CursorMalformed(Str)`.
- `request(query, defaultSize, maxSize)`: reads `limit` and `cursor`; out-of-range limits are refused.
- `encodeCursor(key)`, `decodeCursor(token)`: URL-safe base64 of the last key.
- `select(items, keyOf, request)`: pages an ordered in-memory sequence.
- `fromFetched(fetched, keyOf, request)`: pages a store query that asked for `size + 1` rows.
- `linkHeader(base, page, request)`: RFC 8288 `rel="next"`.
- `toJson(page, render)`: `{"items": [...], "next": ...}`.
- `explain(problem)`.

## Grill Log

- **Q:** Offer offset pagination? **A:** No. _Rationale:_ an offset skips or repeats rows when the
  set changes between requests and makes a deep page scan every row before it. _Rejected:_
  `page=`/`offset=` parameters.
- **Q:** Clamp an oversize limit? **A:** No. _Rationale:_ a client asking for 500 and silently
  receiving 100 cannot tell the last page from a clamped one.
- **Q:** Sign cursors? **A:** Not here. A cursor names a key the caller could already see; a service
  that must hide keys encrypts them before `encodeCursor`.

## Dependencies and consumers

- Depends on [[Std Bytes]], [[Std Json]], `Std.Text`, and [[Std Url]].
- Consumed by listing handlers and [[Std Db Query]] callers that fetch `size + 1` rows.

## Referenced by

[[src/Std/_MOC]] · [[architecture/WEB]]
