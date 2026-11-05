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

A read-only window retaining a shared `Array[T]` value: narrowed and walked in place. Later reassignment of the caller's array does not change the retained snapshot.

## Interface

- `Span[T] = { source, offset, extent }`, `of(values)`, `within(values, offset, extent) -> Option[Span[T]]`.
- `Window[T]`: `size`, `get(index) -> Option[T]`, `prefix(count)`, `suffix(count)`, `subspan(offset, count)`, `subspanFrom(offset)`.
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

## Completion contract (#527)

Checked construction compares offset and extent against the remaining source length before addition. Add `subspanFrom(offset)` for the remaining tail. Views retain their backing value as a read-only snapshot; they do not propagate later reassignment of the source variable.

Resolved Grill Log: follow [[C++ Inspired View Coverage]]; add capabilities compatible with Pudu values and checked errors, without a new pointer ABI or implicit allocator state.
