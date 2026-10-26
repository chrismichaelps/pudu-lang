---
type: module
path: "@root/src/Pudu/Compiler/Lower/For.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower For]
---
# Compiler Lower For

## Purpose and interface

`lowerFor` lowers `for` as the evaluator's `evaluateFor` walks it, for a range
written with both ends in the loop head and for a type whose methods include
`begin` and `advance`. The loop is an ordinary `CoreLoopValue` under the loop's
own frame, so labels, `break`, `continue` and Never work as in `while`. The
loop's value is unit.

## Ranges

Both ends run once, start first, and must be `Int`, the type every range
element has in the evaluator. `next` holds the element about to be taken, and
each turn takes it before the body runs, so `continue` lands after the step. An
inclusive range compares `next` with its last element before stepping, so
`..=` up to the largest `Int` ends without an overflow. An exclusive one steps
only while below its end, where `end - 1` cannot overflow either.

## Sequences

The value runs once into a hidden local, `begin` runs once on it, and each turn
matches `advance(value, state)`: `None` breaks, and `Some((next, item))` stores
the new state before the body sees the item. That is the order `walk` uses.

## Binders

The binder is lowered with [[Compiler Lower Match]]'s `lowerPattern` against
the element, as an arm whose fallback is unit, so an element that does not
match skips the body, as `matchPattern` does in the evaluator.

## Resolved Grill Log

- **Q:** Why not rewrite to `while` in syntax? **A:** Generated syntax has no
  checked facts, and every lowering step reads facts at exact spans.
- **Q:** Break values? **A:** Checking rejects a value carried out of a `for`;
  the loop's value is unit either way.
- Range values held in variables, Str, tuples, arrays, sets and maps refuse
  until they have native forms.

## Dependencies and consumers

[[Compiler Lower Control]] · [[Compiler Lower Match]] · [[Compiler Lower Method]] ·
[[Compiler Lower State]] · [[Compiler Lower Types]] · [[Core IR]]

## Arrays (#556)

Resolved Grill Log: an array runs once, its length is read once, and each turn
declares the next item, as walking the evaluator's item list does.

## Body tails (#558)

The body goes through `droppedTail` from [[Compiler Lower Control]].

## Maps and sets (#561)

A map walks `entries()` and a set `toArray()`, listed before the body runs.

## Str, tuples and payloads (#562)

Resolved Grill Log: a Str walks `chars()`; a tuple runs once into a local and
walks its members (the checker makes them one type); a sum with no `begin`
and `advance` walks the payload of the variant it holds, through a match whose
arms answer arrays, after the sequence protocol was looked for, which is
`evaluateFor`'s order. Each lists its items before the body runs.

## Referenced by

[[Compiler Lower Body]]
