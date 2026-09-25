---
type: module
path: "@root/lib/Std/App/Idempotency.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, application, http, reliability]
aliases: [Std App Idempotency]
---

# Std App Idempotency

## Purpose and interface

Safe retries for state-changing requests: a request repeated with the same `Idempotency-Key` gets
the stored answer instead of running twice.

Exports:
- `type Held`, `type Store`, `type Shared = { lock, held }`,
  `type Decision = Proceed | Replay(Http.Response) | Mismatched | Pending | Full`.
- `HEADER` (`Idempotency-Key`), `REPLAYED` (`Idempotent-Replayed`).
- Pure store: `store`, `decide`, `begin`, `finish`, `release`, `prune`, `live`.
- Request reading: `keyOf`, `fingerprintOf` (SHA-256 of method, path, and body).
- `shared(lifetime, capacity)`, `guarded(shared, clock) -> Route.Middleware`.

## Semantics

- Safe methods and keyless requests pass through.
- A key reused with a different fingerprint is 422; a key whose first request is still running is
  409; a store full of live keys is 503. Each refusal is an [[Std App Problem]] body.
- A 5xx answer releases the key, so a retry after a failure runs again; any other answer is stored
  for `lifetime` milliseconds.
- Decide-and-begin runs under one lock, so two concurrent first requests with one key cannot both run.

## Grill Log

- **Q:** Store in-process only? **A:** The store is a value behind a cell; a multi-instance service
  shares keys by routing them to one instance or by persisting `Store` entries through
  [[Std Db]]. _Rejected:_ a hidden global table.
- **Q:** Store 5xx answers? **A:** No. _Rationale:_ a transient failure replayed for the key's lifetime
  turns one outage into a permanent failure for that client.
- **Q:** Why fingerprint the body? **A:** A client bug that reuses a key for a different order must be
  refused, not answered with the first order's receipt.

## Dependencies and consumers

- Depends on [[Std App Problem]], [[Std Crypto]], [[Std Sync]], and [[Std Http Server Route]].
- Consumed through `App.wrapping`.

## Referenced by

[[src/Std/_MOC]] · [[architecture/WEB]]
