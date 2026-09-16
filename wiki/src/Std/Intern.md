---
type: module
path: "@root/lib/Std/Intern.pudu"
fidelity: Active
subsystem: "[[architecture/STDLIB]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib]
aliases: [Std Symbol Interner]
---

# Std Symbol Interner

## Purpose, interface, and invariants

A persistent table assigning insertion-order integer IDs to strings. `empty`, `intern`, `internAll`,
`lookup`, `resolve`, and `size` support compiler symbol tables without global state. Reinterning an
existing spelling preserves its ID. `resolve` bounds-checks IDs and returns `None` for invalid ones.
Updates return the new pool explicitly; callers must thread that pool forward. Independent pools or
forked snapshots do not share an ID namespace. The public pool record is a library representation,
not an opaque compiler identity or serialized cross-compilation key.

Uses the existing ordered `Map[Str, Int]` and persistent `Array[Str]`; lookup cost includes string
comparison. No hash-map or speed guarantee is claimed. The interner is deterministic for the same
insertion sequence. For externally constructed pool records, the names and index must agree;
`lookup` checks a stored ID against the corresponding spelling before returning it.

## Grill Log

- **Q:** Use a process-global interner for all compiler runs? **A:** No; state is an explicit value,
  allowing independent runs and deterministic snapshots.
- **Q:** Treat IDs from different pools as globally meaningful? **A:** No; a compiler must scope IDs
  to its own session and serialize spellings or a declared table when crossing that boundary.

## Dependencies and consumers

Uses built-in bytes, text, arrays, maps, and failure carriers. Intended for explicit import by
compiler and parser clients. No foreign calls, hidden IO, or host primitives are introduced.

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]] · [[architecture/FFI-SELF-HOSTING]]
