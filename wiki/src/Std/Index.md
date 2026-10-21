---
type: module
path: "@root/lib/Std/Index.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, indexing, operator]
aliases: [Std Index]
---

# Std Index

## Purpose

The protocol `[]` uses for types that are not built in: `Index[K, V]` for reading and `IndexMut[K, V]` for assigning.

## Interface

- `Index[K, V]`: `fn index(self: &Self, key: K) -> V`.
- `IndexMut[K, V]`: `fn setIndex(self: &mut Self, key: K, value: V) -> ()`.

## Invariants

- `value[i, ...]` calls `index` once with a key built from the indices: an array of them when `K` is `Array[I]`, otherwise one index itself or a tuple of exactly as many indices as `K` has members ([[Type Check Subscript]]).
- Both traits are visible in every module without an import ([[Type Interface Graph]]).
- The target, each index and an assigned value run once each, in that order ([[Compiler Literals]]).
- Implemented by [[Std Span]] (`Index[Int, T]`) and [[Std MdSpan]] (`Index[Array[Int], T]`).

## Grill Log

- **Q:** Return a reference from `index` so elements are places? **A:** The language has no reference results, so `index` returns a value and `setIndex` replaces an element whole. A write into part of an element is refused rather than applied to a copy.
- **Q:** One trait with both members? **A:** No; a read-only view such as `Std.MdSpan` implements `Index` alone, and `value[...] = item` on it is a checked refusal.

## Dependencies and consumers

- **Requires:** nothing.
- **Consumed by:** [[Std Span]], [[Std MdSpan]], `test-fixtures/language/MultiIndex.pudu`.

## Referenced by

[[src/Std/_MOC]] · [[grammar/pudu]]
