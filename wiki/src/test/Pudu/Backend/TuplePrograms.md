---
type: module
path: "@root/test/Pudu/Backend/TuplePrograms.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Tuple Programs]
---
# Backend Tuple Programs

## Purpose and interface

Export tupleSuccessPrograms and tupleRefusalPrograms, run by [[Backend Native
Tests]] and, for successes, [[Backend Text Leak Tests]].

## Coverage

Rendering with quoted Str/Char members, nesting, unit, narrow and 128-bit
integers and floats; elementwise equality with NaN and signed zeros;
compareValues ordering including the NaN cases where `<` and `>` both hold;
positions; let patterns with nesting, wildcards and a swap; tuples through
calls, branches, loops, `break` values and mutation; member order and a Never
member; tuple entry results. Refusals: arithmetic and negation on tuples,
after their operands run.

## Grill Log

- **Q:** Where do the NaN answers come from? **A:** From the interpreter, and
  they are what base's Ord defaults give; see [[Backend Frame Values]].

## Referenced by

[[Backend Native Tests]] · [[Backend Text Leak Tests]] · [[src/_MOC]]
