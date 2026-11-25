---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Toolchain/Split.hs"
fidelity: Active
subsystem: "[[Backend]]"
tags: [module, backend, toolchain, split]
aliases: [Toolchain Split]
---

# Backend Toolchain Split

## Purpose and interface

Divides one generated C translation unit into several units that compile at
the same time (#1003). The output is a shared header (`unit.h`), a data unit
(`unit_data.c`) and function units (`unit_N.c`). Every unit includes the
header, so the set links into the same program as the single unit it replaces.
The pass is a text pass over the emitted C. It changes no behaviour and
produces no output of its own.

```haskell
splitUnits :: Int -> Text -> [(FilePath, Text)]
```

[[Backend Toolchain]] calls the pass only when `unitPlan` chooses more than one
unit, and compiles the returned units concurrently.

## Algorithm and invariants

- The pass reads top-level items by brace depth. Each item keeps the
  conditional directives (`#if`, `#elif`, `#else`) that enclose it, and those
  directives are replayed around any item placed in another unit.
- Comment blocks, blank lines and a lone `__attribute__((...))` line pass
  through unchanged.
- Header, present in every unit:
  - directives and types;
  - prototypes: external functions, except functions copied into every unit;
  - inline helpers, meaning items declared `inline` or with a runtime macro
    ending in `_INLINE`, provided they hold no local `static`;
  - read-only data whose declaration has no pointer. A `const` before a pointer
    qualifies what it points at, so such data is not read-only data.
- Data unit, defined once: every other piece of data. The header carries one
  `extern` per declarator. A brace-initialized array has its length written
  into its `extern`, because code reads the array's size and compares addresses
  into it. The site table is one such array.
- Function units, defined once: every other function, including an inline
  helper that holds local statics. Each is defined once, with `static` and
  `inline` removed, in the function unit that a size balance picks.

## Negative Logic (Prohibited Paths)

- No retagging of every emitter source. The pass classifies the text it
  receives, so the emitters keep producing raw C lines.
- No duplicated mutable state. A variable, hook or site table has exactly one
  definition, in the data unit.
- No copied aggregate helpers. A small helper is defined once, never copied into
  each unit.
- No `static` function left referenced from another unit.

## Dependencies and consumers

Consumes the C text assembled from the emitter sources, including the
[[Backend Emit]] and runtime parts. Called by [[Backend Toolchain]], which
decides the unit count, compiles the units and removes their directory
afterwards. The forced-split property suite exercises the pass by splitting
every program.

## Grill Log

- **Q:** Why a text pass over the emitted C rather than retagging every emitter
  source? **A:** The unit is assembled from about fifteen sources of raw C
  lines. The pass needs only the shapes those sources already share (top-level
  items, brace depth, directives), so one pass covers all of them and no emitter
  changes its output. _Rejected:_ a typed item tag on every emitted line, which
  touches every emitter for a property the text already carries.
- **Q:** Which state bugs did the forced-split suite catch, and what rules
  followed? **A:** Three. (1) A mutable variable carrying
  `__attribute__((unused))` was read as a prototype. Its definition was
  duplicated, which duplicated the ownership transfer mask and corrupted the
  heap. Rule: a line with a variable definition is data, whatever attribute it
  carries. (2) A mutable function-pointer hook was read as read-only because of
  a `const` before `*`. Blame then went to the wrong site. Rule: a `const`
  before a pointer qualifies the pointee, so a pointer declaration with mutable
  storage is not read-only data. (3) Copied site tables broke address identity,
  because code compares addresses into the table. Rule: every table is defined
  once in the data unit and its length is carried into the `extern`.
- **Q:** Why was copying small aggregate helpers into every unit dropped?
  **A:** Link-time optimization across units already inlines them, and the
  copies still corrupted the heap, because each copy carried its own state. One
  definition is both smaller and correct. _Rejected:_ per-unit copies of
  aggregate helpers.

## Referenced by

[[src/Pudu/Backend/_MOC]] · [[Backend Toolchain]] · [[Backend Toolchain Cache]] · [[Backend Toolchain Process]]
