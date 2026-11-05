---
type: module
path: "@root/lib/Std/Desktop/Shape.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, desktop, ipc, typescript]
aliases: [Std Desktop Shape]
---

# Std Desktop Shape

## Purpose and interface

A value's wire form, described once and rendered as TypeScript. `Shape` is the description;
`trait Describe { fn describe() -> Shape }` gives a type its description, with implementations for
`Int`, `Float64`, `Decimal`, `Str`, `Bool`, `()`, `Json`, `Bytes`, `Array[A]` and `Option[A]`, and
`derive Describe` for records and sums. `typescript(shape)` renders an expression;
`declarations(shapes)` renders every named type reachable from a set of shapes, each once.

## Semantics

- The description follows exactly what [[Std Json]] `Encode` writes: a record is an object keyed by
  wire names (`@json` renames, `@skip` omits), an `Option` is `T | null`, a sum is a union of
  one-key objects whose value is a tuple for a positional payload, an object for a named one, and
  `[]` for a unit variant. `Bytes` is an `ArrayBuffer`, used only by raw commands.
- A derived description is a `Reference` holding its name and a function producing its body, so a
  recursive type renders as a named alias that refers to itself instead of recursing forever.
- Keys that are not identifiers are quoted. Declarations are sorted by name so generated files
  are stable across runs.

## Grill Log

- **Q:** Why describe types in Pudu rather than read them from the compiler? **A:** The wire form is
  decided by `Json.Encode`, which is Pudu code with attributes; a description derived beside it with
  the same attributes cannot disagree with it, while one read from declarations would have to
  re-implement the encoder's rules.
- **Q:** Why a function inside `Reference`? **A:** A derived description of a recursive type would
  otherwise call itself while being built. Rendering keeps a set of names already declared and
  forces each body once.

## Dependencies and consumers

Uses [[Std Meta]] and [[Std Json]]. Consumed by [[Std Desktop Ipc]].

## Referenced by

[[src/Std/_MOC]] · [[architecture/DESKTOP-WEBVIEW]]
