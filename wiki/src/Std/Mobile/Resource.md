---
type: module
path: "@root/lib/Std/Mobile/Resource.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, mobile, native, ui, network]
aliases: [Std Mobile Resource]
---

# Std Mobile Resource

## Purpose and interface

Pure table of the keyed requests a screen needs, and the commands that make the platform match it. The program describes what it wants to show as a list of `Need` values after each event. The table decides which requests are in flight, which results are fresh, which retries are waiting and which entries are kept. The host only executes the `Command` values: it sends, cancels and wakes. Every rule can be pinned by fixtures without a network. The host is [[iOS Host Fetch]] on iOS.

Types:
- `Policy = { freshFor: Int, keptFor: Int, retries: Int }`: how long a settled result is served before it is asked for again, how long an entry is kept once nothing describes it, and how many failed attempts pass before a failure is shown. Times are milliseconds.
- `Request = { method, url, headers: Array[(Str, Str)], body }`: what the platform sends.
- `Need = { key, request, policy }`: a keyed request the program needs now. The key names the data, never the moment, so every place that describes the same key shares one request.
- `Status = Pending | Loaded(Int, Str) | Failed(Int, Str)`: what the program sees for a key. A loaded result carries its status and body. A failure carries its status (0 when nothing arrived) and its body or reason.
- `Response = { generation: UInt32, status: Int, body: Str, retryAfter: Int }`: an answer the platform delivered for a request generation. `retryAfter` is the Retry-After delay in milliseconds, or -1 when it asked for none.
- `Command = Start(UInt32, Request) | Cancel(UInt32) | Wake(Int)`: send a request under a generation, cancel one, or wake the program at an absolute time so a waiting retry can start.
- `Table`: every key's entry, the last generation handed out, how many undescribed entries are kept, and the generator behind retry jitter.

Exports:
- `table(capacity: Int, seed: UInt64) -> Table`: an empty table keeping at most `capacity` undescribed entries. `seed` makes retry jitter reproducible.
- `reconcile(held: Table, needs: &Array[Need], now: Int) -> (Table, Array[Command])`: the table after `needs` describes what the program needs at `now`, and the commands that match the platform to it.
- `received(held: Table, response: &Response, now: Int) -> Table`: the table after the platform delivered a response at `now`.
- `observe(held: Table, event: &View.Event, now: Int) -> Table`: folds a `Fetched` event into `received` and a `MemoryLow` event into `trimmed`. Other events leave the table unchanged.
- `written(commands: &Array[Command], now: Int) -> Bytes`: the view stream that carries the commands to the platform. A wake is written as the delay from `now`.
- `status(held: &Table, key: Str) -> Status`: what the program sees for `key`; `Pending` when the key is unknown.
- `trimmed(held: Table) -> Table`: drops every entry nothing describes.
- `size(held: &Table) -> Int`: how many entries the table holds, described or kept.

Constants: first retry ceiling 500 ms, longest delay 30000 ms, `NEVER` -1, `NO_FLIGHT` generation 0. Transient statuses are 0, 408, 425, 429, 500, 502, 503 and 504.

## Behaviour

- One request in flight per key. A described key starts a request only when no generation is in flight for it, its result is not fresh and no retry is waiting.
- Nothing is sent while fresh. A result is fresh when it settled less than `freshFor` ago.
- A key described twice in one call is handled once.
- A changed request for a key cancels the old generation in flight and starts the new request from `Pending`. The same request keeps its entry, and the description refreshes its policy.
- An undescribed key has its request cancelled. Its entry is kept for `keptFor` after it was last needed, within capacity, newest first. Kept entries are never retried, and `trimmed` drops them under memory pressure.
- A transient status retries after a full-jitter delay: a draw from 1 ms up to the ceiling for that attempt. The ceiling starts at 500 ms, doubles per attempt and is capped at 30 s. The delay is never shorter than Retry-After.
- While a retry is waiting, a loaded result stays `Loaded`. Otherwise the status is `Pending` until attempts exceed `retries`, then `Failed`. Retries continue while the key is described.
- A 2xx response settles the key as `Loaded`. A 304 settles it and keeps the status it held. Any other status that is not transient settles it as `Failed` at once and is not asked for again while fresh.
- A response whose generation is not in flight is dropped and changes nothing.
- `reconcile` emits at most one `Wake`, for the earliest waiting retry of a described key.
- Conditional requests add no headers here. The platform's protocol cache revalidates them.

## Negative Logic

- No I/O and no clock. The caller passes `now`, and the seed fixes the jitter.
- No request is executed by the table. `written` only spells the commands; [[Std Mobile Stream]] spells each instruction.
- No body is kept beyond the policy, and no conditional header is written.
- No pagination, no background pause and no network-change handling. Those are not in this module.
- A `Woke` event is not folded by `observe`; the program's next `reconcile` starts the retry that is due.

## Dependencies and consumers

Depends on [[Std Mobile Stream]] for the FETCH, CANCEL and WAKE words, on [[Std Mobile View]] for the `Event` type, and on `Random` for jitter. Consumers: the program, whose loop calls `observe`, `reconcile` and `written` after each event, and [[Std Mobile Events]] through the `Fetched` decoding. The example is [[Native Remote Example]].

## Resolved Grill Log

- **Q:** Why a pure table with commands? **A:** Every rule can be pinned by fixtures without a network, and the host only executes. _Rejected:_ a host that decides when to retry, which would leave the rules untestable outside a simulator.
- **Q:** Why full jitter? **A:** Clients that failed together must not retry together.
- **Q:** Why keep a loaded result while retrying? **A:** A failed refresh must not erase data the user is reading.
- **Q:** Why keep undescribed entries for a time? **A:** A screen that scrolls away and comes back shows its data at once, and the policy's keep time bounds how long that holds.

## Referenced by

[[src/Std/_MOC]] · [[Std Mobile Stream]] · [[Std Mobile View]] · [[iOS Host Fetch]] · [[Native Remote Example]] · [[Uses Mobile Resource]] · [[Native Render Skipping]]
