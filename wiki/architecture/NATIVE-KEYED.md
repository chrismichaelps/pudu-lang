---
type: architecture
status: IMPLEMENTED
tags: [architecture, backend, collections]
aliases: [Native Maps and Sets]
---
# Native Maps and Sets

`Map[K, V]` and `Set[T]` are boxes holding the root of a persistent balanced
tree ([[Native Persistent Trees]]), shared between every value that reached
it and copied only along the path an update changes.

## Contract

- **Order.** Keys are kept in `compareValues` order. Every walk, rendering
  included, is ascending.
- **Duplicates.** A map keeps the first key it stored and the newest value; a
  set keeps the first member. `merge` takes the right map's keys and values;
  `union` keeps the left set's members; `intersect` and `difference` keep the
  left set's.
- **Values.** Rendering is `{k: v, ...}` and `#{a, ...}`. `==` compares
  entries pairwise; ordering inside a tuple compares entry by entry, then size.
- **Failures.** A key that cannot be ordered is E7008 with `valueKind`'s name
  for it ([[Compiler Lower Keyed]]).
- **Cost.** Logarithmic lookups and updates, like the evaluator's trees.

## Not yet

The accelerated `wordMap*`, `multiMap*` and `buckets*` builtins and FlatMap
refuse with E6001.

## Resolved Grill Log

- One tree implementation for every key and value type, parameterised by an
  ops table of per-type functions, rather than one tree per type.

## Referenced by

[[Native Emission Coverage]] · [[Compiler Lower Keyed]] · [[Backend Emit Keyed]] · [[Native Persistent Trees]]
