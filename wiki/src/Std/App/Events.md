---
type: module
path: "@root/lib/Std/App/Events.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, application, events, outbox]
aliases: [Std App Events]
---

# Std App Events

## Purpose and interface

In-process publish/subscribe and a transactional outbox, so the modules of one service react to
each other's facts without calling each other, and nothing is announced for work that rolled back.

Exports:
- `type Event = { topic, id, at, payload }`, `type Subscriber`, `type Bus`, `type Delivery`,
  `type Outbox`.
- `event`, `bus()`, and the `Subscribing` chain `.on(pattern, name, handle)`; patterns are an exact
  topic, a dotted prefix `order.*`, or `*`.
- `matches`, `audience`, `publish` (every subscriber runs; each refusal is reported by name).
- `outbox(limit)`, `stage`, `discard`, `drain(outbox, bus)`, `pendingOf`, `deadOf`.
- `toJson`, `fromJson` for a durable outbox table or a log line.

## Semantics

- Stage events inside a unit of work; `discard` on rollback, `drain` after commit.
- An event any subscriber refused stays pending and is retried on the next drain; after `limit`
  failed deliveries it moves to `dead` rather than blocking the ones behind it.
- Subscribers run in the order added, so a ledger written before a notification stays before it.

## Grill Log

- **Q:** Deliver asynchronously on a hidden thread? **A:** No. _Rationale:_ delivery is a call the
  service makes at a point it chooses — after a commit, inside a [[Std App Work]] job — so ordering
  and failure are visible. _Rejected:_ a background dispatcher.
- **Q:** Why an outbox in an in-process bus? **A:** The failure it prevents is local: announcing an
  order that the database then refused. Persisting `toJson` rows makes the same outbox durable.

## Dependencies and consumers

- Depends on [[Std Json]].
- Consumed by services and [[Std App Work]] jobs that drain outboxes.

## Referenced by

[[src/Std/_MOC]] · [[architecture/WEB]]
