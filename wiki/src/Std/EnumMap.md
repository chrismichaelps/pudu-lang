---
type: module
path: "@root/lib/Std/EnumMap.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
depth_score: 0.35
depth_status: MEDIUM
coupling: 1.0
interface_stability: 0.8
tags: [module, stdlib, medium]
aliases: [Std EnumMap]
---

# Std EnumMap

## Purpose

A map over a fixed domain of keys where every key has a value, so reading one answers a value rather
than an `Option`.

## Interface

22 exports: the `EnumMap[K, V]` type, construction (`filled`, `from`), reads (`get`, `getOr`, `find`,
`keys`, `values`, `pairs`, `size`, `isEmpty`, `containsKey`), writes (`set`, `adjust`, `mapValues`,
`mergeWith`), and queries (`fold`, `keysWhere`, `countValues`, `all`, `any`, `toMap`).

### Governance

- The domain is **settled when the map is built** and does not grow. `set` with an unknown key
  changes nothing. The totality of `get` rests entirely on this, so a map whose keys could be added
  to would be an ordinary map wearing this one's type.
- `get` is **total for any key in the domain**, which is the whole reason the module exists. It
  panics for a key outside the domain: the caller named the domain, so that is a defect in their own
  code rather than an input a program could receive. This is the documented panic the standard
  library's rules allow, and `find` is the answer for a key that arrived from outside the program.
- Keys keep the order the domain named them in, **not** a sorted order. A domain is usually written
  in an order that means something — Monday first, Debug below Error — and sorting would replace the
  author's order with the spelling of the names.
- A key listed twice in the domain becomes one slot, at its first position. Two slots for one key
  would leave no way to say which is meant.
- `keysWhere` answers keys rather than a smaller map, because a map with keys removed is no longer
  total over the domain it claims — returning one would hand back the `Option` this module removes.

### Linkage

- **Requires:** [[Std List]].
- **Consumed by:** programs; nothing in `Std` depends on it.

## Algorithm

Two arrays held in step: the domain's keys, and a slot per key. A key's position in the first is its
value's position in the second, so a read is a search of the domain followed by an index.

The domain is searched rather than hashed because these domains are small by construction — the
cases of a status, the days of a week — and a search over a handful of keys costs less than the
machinery for avoiding it.

## Negative Logic (Prohibited Paths)

- No growth of the domain through any operation, which would break `get`'s totality.
- No sorting of the domain, which would discard the order the author wrote.
- No silent fallback in `get`; a key outside the domain has no honest value to invent.
- No operation answering a map with fewer keys than its domain claims.

## Edge Cases

- A map over an empty domain is legal and holds nothing; it is the one case with no key to ask about.
- `set` and `adjust` with a key outside the domain leave the map unchanged rather than reporting.
- `mergeWith` keeps the first map's domain, and a key the second map lacks keeps the first's value
  untouched, so combining a full domain with a partial one does not force the caller to handle a
  domain mismatch on every call.

## Depth

DEPTH 0.35 (MEDIUM). One invariant — domain and slots the same length, in the same order — and a
totality that follows from it.

## Grill Log

- **Q:** Why does `get` panic rather than answer `Option`? **A:** Because answering `Option` would
  make it the ordinary map this module exists to be an alternative to. _Rationale:_ the caller named
  the domain, so a key outside it is a defect in their code, and the standard library's rules permit
  a panic for exactly that while requiring it be documented. `find` and `getOr` cover the cases
  where the key's origin is not under the caller's control. _Rejected:_ a `get` returning `Option`,
  which leaves the module with no reason to exist.
- **Q:** Why not derive the domain from the key type? **A:** Because the language has no way to
  enumerate a type's values, and inventing one for this module would be a language feature decided
  by a library. _Deferred:_ if enumerable sums are ever added, `filled` gains an overload that takes
  no domain; the shape here does not have to change for that.
- **Q:** Two parallel arrays rather than a `Map` plus a key order? **A:** Two arrays. _Rationale:_
  the domain is fixed, so the position of a key never changes after construction, and a position
  that never moves is exactly what an array index is. A `Map` would re-answer a question already
  settled at build time on every read. _Rejected:_ reusing [[Std LinkedMap]], whose key order can
  change and which therefore cannot promise totality.
- **Q:** Should `set` report an unknown key rather than ignoring it? **A:** Not as its default.
  _Rationale:_ the common use is folding over data whose keys are a superset of the domain — counting
  log lines into known levels, say — where reporting would force a `Result` at every step of a loop
  that has nothing to do about it. _Deferred:_ a checked `setChecked` returning `Result` if a caller
  needs the distinction.

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]]
