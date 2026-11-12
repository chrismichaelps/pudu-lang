---
type: architecture
tags: [backend, native, collections]
aliases: [Native Indexed Stores]
---
# Native Indexed Stores

`Buckets[V]` is a native value: `CoreStoreType V`, a box holding the root of
the shared balanced tree, keyed by a platform Int. It reuses the map helpers
at key Int and differs only in its type name, its rendering (`#[key: value]`),
its runtime kind (`store`) and its method table.

| Surface | Native form |
| --- | --- |
| `bucketsOf()` | the store built from an empty array of (Int, V) pairs |
| `size`, `isEmpty`, `keys`, `values` | the keyed operations of the same name |
| `get` | `Some(lookup)` after a successful contains, else `None` |
| `insert`, `remove` | the keyed operations, on a narrowed key |
| `toText`, `show`, `display` | `#[` entries in key order `]` |
| `==`, ordering, comparability | entry by entry in key order, then size |
| `hashOf(value)` | `KeyedHash` over text, bytes or an integer; other values hash the text they show as |
| `mixHash(value)` | `KeyedMixHash` over the Int operand |
| `multiMapAdd`, `multiMapContains` | Core over the record's two maps |

A store key is the Int folded into one machine word: lowering wraps it with
`&+ 0` before every probe, so a deferred magnitude at or above 2^63, which is
what `mixHash` answers half the time, addresses the entry the interpreter's
narrowing addresses. `keys()` answers the narrowed values.

`mixHash` mixes the operand's low 64 bits with a per-process seed and answers
the unsigned word as an Int. The seed is read once from the operating
system's random source; where that cannot answer it is the interpreter's
fixed constant. Placement is not observable: no conformance program prints a
mixed value.

`hashOf` is deterministic and matches the interpreter bit for bit: the
multiply-and-xor walk over UTF-8 bytes or raw bytes; for an integer of any
kind, over its magnitude's bytes from the highest non-zero one, followed by
a sign byte.

A builtin taken as a value fails at the call made through it, as a method
value does. The function table marks both, so a checked operation inside a
builtin body reports where the interpreter reports it.

`multiMapAdd` runs its three operands in order, tests the key and then the
(key, value) pair for orderability where their types could hold a function,
appends to the key's group or starts one, counts the pair with a checked add
at the call, and answers the record with both maps replaced. Both maps take
the new key's spelling, as the interpreter's insertion does.
`multiMapContains` is a contains test of the pair in the occurrence map.

## Resolved Grill Log

- **Q:** A second tree runtime for stores? **A:** No. Key order over narrowed
  Ints is the interpreter's IntMap order, so the map helpers answer every
  method. Rejected: a hashed C table, whose iteration order would need a
  separate proof.
- **Q:** Where is the key narrowed? **A:** In lowering, with the existing
  wrapping add, so no helper takes a second key convention. Rejected: a
  store-only helper family.
- **Q:** How is an empty store made without a new frame value? **A:** Through
  the existing from-array builder over an empty pair array. Rejected: a new
  Core and frame shape for one constant.
- **Q:** May conformance print `mixHash`? **A:** No. The seed differs per
  process; programs test determinism within a run, range and store
  round-trips.
- **Q:** Does `multiMapAdd` need its fused interpreter representation?
  **A:** No. The integer-pair index is a representation of the same map;
  rendering, order and membership are those of `Map[(K, V), Int]`.
- **Q:** Which insert keeps which spelling? **A:** `KeyedPut` replaces an
  equal key's spelling; `KeyedInsert` keeps the held one. Only MultiMap
  updates use `KeyedPut`.

## Referenced by

[[architecture/_MOC]] · [[Native Emission Coverage]] · [[Native Indexed Store Delivery]] · [[Compiler Lower Store]] · [[Compiler Lower Multi Map]] · [[Native Hash Mixing]] · [[Backend Store Programs]]
