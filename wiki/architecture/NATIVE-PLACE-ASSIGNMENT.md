---
type: architecture
aliases: [Native Place Assignment]
---
# Native Place Assignment

An assignment target is a place: a local, then any mix of field and index
steps (`p.x`, `list[1]`, `grid[1][0]`, `points[0].tags[0]`). The root local
is given a copy of what it held with the one field or element along the
path replaced, as `Eval.Place.storePlace` does; nobody else holding the old
value sees it change.

Order follows the evaluator: each index along the path, root to leaf, runs
into a temporary; then the value; then the store. Rebuilding descends one
step at a time. A field step uses a record update. An index step reads the
element it descends into with the bounds-checked array read, and writes back
with `ArrayReplaceAt`, which checks bounds first. Both are placed at the root
name's span, so an index out of range is E7004 "index out of range" there,
before anything deeper is looked at, exactly where the interpreter reports
it. `ArrayReplaceAt` changes the items in place when the array's box has one
owner and copies otherwise; a top-level `list[i] = v` takes the local, so the
common case does not copy.

A target with no native form refuses with E6001. It must never be handed
back to expression lowering, which only wraps it into a statement again.

## Resolved Grill Log

- **Q:** Read the element with the expression's own span? **A:** No; the
  evaluator reports every failure of a place at its root name.
- **Q:** Rebuild with a pointer into the frame? **A:** No; values are shared
  by reference count, so an in-place write through a pointer would change
  every holder. The copy is skipped only when the box is uniquely owned.
- **Q:** Map entries? **A:** Checking refuses them (E3077); nothing to lower.

## Evidence and remaining scope

Locals, fields, elements and nested mixes, the old value kept by another
binding, negative and past-the-end indices at the root span, owned elements
released once; both evaluators, Clang, GCC 15 and ASan/UBSan. `&mut`
writeback builds on this and is its own slice.

## Referenced by

[[architecture/_MOC]] · [[Native Emission Coverage]] · [[Compiler Lower Place]] · [[Backend Place Assignment Programs]]
