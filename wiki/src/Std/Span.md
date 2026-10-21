---
type: module
path: "@root/lib/Std/Span.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, view, sequence]
aliases: [Std Span]
---

# Std Span

## Purpose

A non-owning window onto a stretch of an `Array[T]`: read, narrowed and walked in place.

## Interface

- `Span[T] = { source, offset, extent }`, `of(values)`, `within(values, offset, extent) -> Option[Span[T]]`.
- `Window[T]`: `size`, `get(index) -> Option[T]`, `prefix(count)`, `suffix(count)`, `subspan(offset, count)`.
- `Index[Int, T]` ([[Std Index]]): `span[i]` reads in place and panics outside the span, never reaching the rest of the array.
- `Sequence[Int, T]`, overriding `toArray` (one structural slice), `count`, `isEmpty`, `first` and `last`, which a span answers without walking.

## Invariants

- `0 <= offset` and `offset + extent <= source.length()` for every span this module builds.
- Narrowing clamps to the span, so a chain of narrowings always answers a span. `within` is the one constructor that refuses, because it is where a caller states a range it expects to exist.
- Reading by position costs one array index; narrowing allocates one record and copies nothing.

## Grill Log

- **Q:** Clamp or refuse an out-of-range `prefix`/`subspan`? **A:** Clamp, as `Str.take` and `Array.slice` do; a pipeline of narrowings reads flat with no `?` between steps. Refusal stays available through `within`. _Rejected:_ `Option` on every narrowing.
- **Q:** Call them `first(n)`/`last(n)` as the reference API does? **A:** No; `first()`/`last()` already answer the end items through `Sequence`, and one type may not have two members of one name. `prefix`/`suffix` say what they keep.
- **Q:** Copy on `toArray` element by element? **A:** No; the array's own `slice` shares structure and costs a walk of its index, not of the items.

## Dependencies and consumers

- **Requires:** [[Std Iter]].
- **Consumed by:** programs; `test-fixtures/stdlib/UsesSpan.pudu`.

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]]
