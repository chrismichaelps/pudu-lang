---
type: module
path: "@root/lib/Std/PrefixTrie.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
depth_score: 0.5
depth_status: MEDIUM
coupling: 0.0
interface_stability: 0.8
tags: [module, stdlib, medium]
aliases: [Std PrefixTrie]
---

# Std PrefixTrie

## Purpose

Text keys held by their characters, so the entries beginning with a prefix can be asked for.

## Interface

25 exports: the `PrefixTrie[V]` type, construction (`empty`, `fromPairs`, `fromKeys`), exact reads
(`get`, `getOr`, `containsKey`, `keys`, `values`, `pairs`, `size`, `isEmpty`), prefix reads
(`withPrefix`, `keysWithPrefix`, `countWithPrefix`, `hasPrefix`, `under`, `longestPrefixOf`), writes
(`insert`, `remove`, `merge`, `filter`, `mapValues`), and `fold`, `toMap`.

### Governance

- A key is a **path through characters**, so walking a prefix touches one node per character of the
  prefix rather than one entry per key in the collection, and a stem shared by many keys is stored
  once.
- Keys are **text only**. That is the price of the shape and is stated on the type.
- Removal **prunes**: a node left holding nothing and leading nowhere is dropped on the way back up.
  Without this, a trie that is filled and emptied keeps the skeleton of every key it ever held.
- A key that is a prefix of another key keeps its own value. `car` and `carpet` are two entries, and
  the node for `car` holds a value *and* children.
- Iteration is depth-first through children in character order, so results come out **in key order
  without anything being sorted**.
- No partial functions; every prefix query answers an empty array rather than failing.

### Linkage

- **Requires:** nothing beyond the prelude.
- **Consumed by:** programs; nothing in `Std` depends on it.

## Algorithm

Each node holds an optional value and a `Map[Char, PrefixTrie[V]]` of children. One private
`descend` walks a key's characters and is what every read is built from; `collect` gathers a subtree
with the path that reached it. A prefix query is `descend` followed by `collect`, so its cost
follows the prefix and the number of matches rather than the size of the trie.

`insert` and `remove` rebuild only the path they touch, so the rest of the trie is shared with the
value they came from rather than copied.

`longestPrefixOf` needs no comparison afterwards: every prefix of the text lies on one downward
walk, so the last value seen on the way down is the longest match.

## Negative Logic (Prohibited Paths)

- No answering a prefix query by reading every key, which is what the shape exists to avoid.
- No node retained that holds no value and has no children.
- No sorting of results; the order falls out of the walk, and sorting would mean it had not.
- No key type other than text.

## Edge Cases

- A prefix that is not itself a key has no value of its own, though it may have many keys beneath.
- Removing a key that is a prefix of another leaves the longer key reachable.
- Removing every key leaves a trie that reports itself empty, not a skeleton of empty nodes.
- `under` on an absent prefix answers an empty trie rather than failing.
- `longestPrefixOf` answers `None` when nothing matches, and can match the empty key when one is
  stored.

## Depth

DEPTH 0.50 (MEDIUM). One walk, one collection, and a pruning rule that keeps removal honest.

## Grill Log

- **Q:** Why not use [[Std SortedMap]] and take a range? **A:** It is a real alternative and closer
  than `Map`, so the module says so. _Rationale:_ a range scan over sorted text compares whole keys
  at each step, where this walks the shared prefix once and then reads only matches; and a stem
  shared by a thousand keys is stored a thousand times there and once here. _Rejected:_ shipping
  only the range form, which is worse at exactly the workload the shape is for.
- **Q:** Is a node per character wasteful for keys that share nothing? **A:** Yes, and that is the
  honest cost. _Rationale:_ a trie of unrelated keys is a node per character with one child each,
  which is worse than a `Map` in both space and time. The type documentation says to reach for this
  when prefixes are asked about and keys overlap, and not otherwise. _Deferred:_ compressing single-
  child chains into one node holding a run of characters, which removes most of that cost and makes
  every operation harder to read; worth doing against a measurement, not before one.
- **Q:** Should `size` be stored rather than counted? **A:** Not yet. _Rationale:_ storing it means
  every node carries a count that every write must maintain, to make one query cheap. _Deferred:_ if
  `size` turns up in a loop; today the prefix queries are the hot path and they do not use it.
- **Q:** Why `Map[Char, _]` for children rather than an array of slots? **A:** Because a slot per
  possible character is an array the size of the alphabet at every node, and Pudu's `Char` is a
  Unicode scalar rather than a byte. _Rejected:_ a fixed-width child array, which is a byte-oriented
  design in a language whose text is not bytes.

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]]
