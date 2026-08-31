---
type: module
path: "@root/lib/Std/LruCache.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
depth_score: 0.45
depth_status: MEDIUM
coupling: 1.0
interface_stability: 0.7
tags: [module, stdlib, medium]
aliases: [Std LruCache]
---

# Std LruCache

## Purpose

A map with a capacity, which discards the entry that has gone longest unused when it is full.

## Interface

22 exports: the `LruCache[K, V]` type, construction (`withCapacity`, `fromPairs`), reads (`get`,
`peek`, `containsKey`, `oldest`, `newest`, `keys`, `values`, `pairs`, `size`, `capacity`, `isEmpty`,
`isFull`), writes (`put`, `remove`, `evict`, `cleared`, `resized`), and `getOrCompute`, `toMap`.

### Governance

- Least recently **used**, not least recently written. Reading keeps an entry alive.
- `get` therefore answers **both the value and a cache**. A read changes which entry is next to go,
  and a read that did not record itself would let an entry the program depends on be discarded as
  unused. `peek` is the deliberate exception, for looking at a cache rather than using it.
- The capacity is honoured on **every** write, including `resized` downward, which may have to
  discard many entries rather than one.
- A capacity below one is kept as zero, and such a cache stores nothing. This is allowed rather than
  refused: it is a cache turned off without the calling code changing shape.
- The recency order is [[Std LinkedMap]]'s `touch`. Nothing here re-implements it.
- No partial functions.

### Linkage

- **Requires:** [[Std LinkedMap]].
- **Consumed by:** programs; nothing in `Std` depends on it.

## Algorithm

A `LinkedMap` whose order is maintained as a recency order, plus a capacity. Every write goes
through `touch`, which moves the key to the end, and then through `trimmed`, which discards from the
front until the size fits. `trimmed` loops rather than removing once, because lowering a capacity
can leave a cache many entries over at a stroke.

## Negative Logic (Prohibited Paths)

- No write that leaves the cache larger than its capacity.
- No `get` that changes the recency order without saying so in its result.
- No unbounded growth from any operation, which would make the type pointless.

## Edge Cases

- A cache of capacity zero accepts writes and holds nothing.
- A negative capacity is kept as zero rather than read as unbounded.
- Rewriting an existing key counts as use and does not grow the cache.
- `fromPairs` given more pairs than the capacity keeps the last ones, since later is more recent.
- `getOrCompute` does not call its function when the key is present, which is the saving asked for.

## Depth

DEPTH 0.45 (MEDIUM). One bound, applied after every write, over an order maintained elsewhere.

## Grill Log

- **Q:** Why does `get` return a cache as well as the value? **A:** Because the read is part of what
  the structure records, and there is nowhere else to put it in a language whose values do not
  change. _Rationale:_ a `get` answering only the value would silently not be an LRU — entries would
  be evicted by write order while the type claimed otherwise. _Rejected:_ recording use only on
  write, which is a different and much less useful policy under an LRU's name.
- **Q:** Then why does `peek` exist? **A:** Because a diagnostic, a report, or an assertion that
  looked through `get` would change the eviction order by observing it. _Rationale:_ the awkwardness
  is real and is the honest shape of the problem; naming the two readings differently at least makes
  the choice visible. _Rejected:_ only `get`, which makes a cache impossible to inspect.
- **Q:** Why build on [[Std LinkedMap]] rather than hold the order directly? **A:** Because `touch`
  is exactly this order and already exists. _Rationale:_ a second copy of that bookkeeping is a
  second place for it to be wrong, and reusing it is the test of whether that module was worth
  having. _Rejected:_ a private key array here.
- **Q:** Should eviction be configurable — least-frequently-used, time-based? **A:** Not in this
  type. _Rationale:_ the policy is what the name promises, and a cache whose policy is a parameter
  cannot state in its type what it will discard. _Deferred:_ separate types if a caller needs them;
  they share almost no code with this one.

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]] · [[Std LinkedMap]]
