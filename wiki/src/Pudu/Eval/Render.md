---
type: module
path: "@root/src/Pudu/Eval/Render.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.3
depth_status: LOW
coupling: 1.0
interface_stability: 0.9
tags: [module, low]
aliases: [Eval Render]
---

# Eval Render

## Purpose

How a runtime value prints, and the short shape-name a diagnostic calls it by.

## Interface

### Signatures

```haskell
renderValue :: Value -> Text
valueKind :: Value -> Text
```

### Governance

- Strings and characters print their quotes and escape their control characters, so a printed `"1"`
  is never mistaken for the integer and a newline never breaks the line.
- `valueKind` is a **runtime shape, not a static type**. A diagnostic that named a static type here
  would be naming something this phase does not know.
- Keyed collections print in key order, which is the order they are held in. Two maps with the same
  entries therefore print alike however they were built, which is the same promise their equality
  makes.
- Both float widths render their normalized numeric value without a runtime suffix; `:type` remains
  where a reader asks about static width.
- An opaque foreign handle renders its declared type and hexadecimal address inside an opaque tag.
  It never renders as source or as an integer a program could reuse.

### Linkage

- **Requires:** [[Eval Value]], [[Decimal Literal]], [[Integer Literal]].
- **Consumed by:** [[Evaluator]], [[Eval Env]], [[Repl Answer]].

## Algorithm

Direct structural recursion over the value shape. No caching, no mutation, no reflection.

## Negative Logic (Prohibited Paths)

- No decision about program meaning; this module only spells a value a reader already has.
- No ordering, comparison, or key eligibility — those are [[Eval Value]]'s and [[Eval Order]]'s.
- No rendering that a reader could mistake for source they could paste back, for the shapes that
  have no source form: a function, a task, and a partially applied method print as opaque.

## Edge Cases

- A function, task, foreign handle, or partially applied built-in method prints as an opaque tag naming what it is,
  because none of them has a written form to print.
- An empty map prints as `{}` and an empty set as `#{}`, which is what distinguishes them.

## Depth

DEPTH 0.30 (LOW). Two total functions over one closed set of shapes.

## Grill Log

- **Q:** Why is this a module of its own rather than part of [[Eval Value]]? **A:** Because #157 moved
  the runtime's total order into [[Eval Value]] — the keyed constructors are keyed by it and cannot
  be declared without it — and that pushed the file to 522 lines, past the 500 the delivery rules
  set. _Rationale:_ printing was the right thing to move because it is a real seam rather than a
  convenient one: how a value prints is not what a value is, and nothing else in [[Eval Value]] read
  these two functions. _Rejected:_ splitting the built-in name tables out instead, which cannot
  leave — `renderValue` reads them, so they would have to come back through an import cycle.
- **Q:** Should `valueKind` have moved with it, or stayed beside the type? **A:** Moved. _Rationale:_
  it answers the same question `renderValue` does — what do I call this for a reader — and the two
  are changed together whenever a value shape is added. _Rejected:_ keeping it in [[Eval Value]],
  which would split one concern across two files to keep an import list shorter.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Eval Value]]
