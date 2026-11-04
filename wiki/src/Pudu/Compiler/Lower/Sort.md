---
type: module
path: "@root/src/Pudu/Compiler/Lower/Sort.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Sort]
---
# Compiler Lower Sort

## Purpose and interface

`sortStatements` turns `items.sortBy(before)` into native loops over two
locals the caller has already evaluated, and names the local holding the
result. [[Compiler Lower Array]] calls it.

## Algorithm

The comparison is the program's own closure, so it can print or fail, and the
sort has to ask it exactly what `Eval.Sort.sortWith` asks. The items are cut
into the runs they already hold: a pair where the second comes before the
first opens a falling run, which keeps going while each item comes before the
last one and is reversed when it ends; anything else opens a rising run, which
ends at the first item that comes before the last one. Then runs are merged in
pairs, round after round, until one is left. A merge takes from the right only
when its item comes before the left's, which keeps the sort stable, and an odd
run out is carried to the next round as is.

## Resolved Grill Log

- **Q:** Why not a runtime sort? **A:** qsort or any other C sort asks a
  different sequence of questions, and a printing comparison would show it.
  The loops also leave the closure call an ordinary call through a value.
- **Q:** What proves the order matches? **A:** A comparison that prints its
  arguments, over sorted, reversed, mixed, empty, single and 300-item inputs,
  plus a stability check ([[Backend Array Pattern Programs]]).

## Dependencies and consumers

[[Compiler Lower State]] · [[Compiler Lower Control]] · [[Core IR]]

## Referenced by

[[Compiler Lower Array]] · [[Native Arrays]] · [[src/Pudu/Compiler/_MOC]]
