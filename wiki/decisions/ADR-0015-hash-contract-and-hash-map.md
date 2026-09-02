---
type: decision
status: ACCEPTED
date: 2026-09-01
tags: [decision, stdlib, hashing, collections]
aliases: [ADR-0015-hash-contract-and-hash-map]
---

# ADR-0015: Hash Contract and Hash Map

## Context

`Std.HashMap` was withheld because Pudu had neither a `Hash` contract nor constant-time bucket
storage. Implementing buckets over `Map` or persistent `Array` would add hashing and collision work
without improving the ordered map's asymptotic lookup. A generic unconstrained runtime `hashOf`
would also let a type's equality and hash disagree without the API stating either obligation.

## Decision

Add `Hash` beside `Eq` and `Ord` in `Std.Order`:

```pudu
export trait Hash { fn hash(self: &Self) -> Int }
```

For every `a` and `b`, `a.equals(&b)` implies `a.hash() == b.hash()`. The converse is never
required. A hash is not a digest and carries no secrecy guarantee. Implementations should distribute
ordinary values well; correctness never depends on distribution.

`Std.HashMap[K: Eq + Hash, V]` is persistent. Its public representation is opaque and delegates
bucket indexing to a runtime value with expected constant-time lookup/insert/remove. Collisions are
resolved by `Eq`, never by hash alone. The runtime may mix a `Hash` result with a per-process seed to
resist attacker-selected bucket concentration without changing equality.

Iteration, rendering, and conversion use **first-insertion order**, retained separately from bucket
placement. Updating an existing key preserves its position; removing and later inserting it creates
a new final position. This keeps observable order deterministic even when bucket seeding differs
between processes. Map equality ignores insertion order and compares key/value membership.

Primitive implementations cover the integer family, floats, decimal, text, character, boolean, and
bytes. Floating implementations normalize signed zero because equality equates them; every NaN is
unequal under existing IEEE equality and therefore imposes no same-hash obligation. User aggregates
implement `Eq` and `Hash` explicitly until controlled derivation exists.

## Public Operations

The first stable surface includes empty/singleton/from-array, size/empty, contains/get/get-or,
insert/insert-with/remove, keys/values/entries, map/filter/fold, merge, equality, and conversion to
ordered `Map`. Every partial lookup returns `Option`; no operation panics on caller input.

## Diagnostics and Compatibility

No syntax changes. Existing programs are unaffected. A missing `Eq` or `Hash` implementation is the
ordinary trait-bound diagnostic at the HashMap call site. Adding the public standard-library module
is a backward-compatible minor semantic-library revision.

## Runtime and Performance Obligations

- Focused conformance covers same-key replacement, collision separation, removal/reinsertion order,
  signed-zero hashing, and user types with custom equality/hash.
- A stress fixture compares results with ordered `Map` over the same operations.
- Benchmarks establish expected constant-time lookup across increasing sizes and reject a hidden
  tree/linear bucket index. No numerical budget is invented before the baseline exists.
- Interpreter/native implementations must preserve results and iteration order; bucket layout and
  seed are not observable.

## Alternatives Rejected

- **Buckets in `Map[Int, ...]`:** lookup remains ordered-tree lookup plus collision work.
- **Unconstrained `hashOf[T]`:** hides the equality/hash law from generic APIs.
- **Hash-table iteration order:** leaks seed and layout into program output.
- **Stable unkeyed bucket hash as the only mixing:** makes network-facing maps easier to concentrate
  adversarially.
- **Cryptographic SHA-256 per lookup:** correct as a digest and prohibitively wrong as a collection
  primitive.

## Grill Log

- **Q:** Does equal hash imply equal key? **A:** No. _Rationale:_ collisions are inherent; `Eq`
  decides identity. _Rejected:_ overwriting on hash alone.
- **Q:** May the runtime seed change iteration order? **A:** No. _Rationale:_ deterministic program
  observations are semantic; bucket layout is not. _Rejected:_ exposing table order.
- **Q:** Automatically hash every aggregate structurally? **A:** Not yet. _Rationale:_ a type may
  define semantic equality that differs from representation, and an automatic hash would silently
  violate the law. _Rejected:_ compiler magic without controlled derivation.

## Referenced by

[[decisions/_MOC]] · [[architecture/STDLIB]] · [[architecture/SEMANTICS]] · [[Std Order]] · [[Std HashMap]]
