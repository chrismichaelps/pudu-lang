---
type: module
path: "@root/src/Pudu/Compiler/Lower/Keyed.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Keyed]
---
# Compiler Lower Keyed

## Purpose and interface

`lowerMapOf`, `lowerSetOf`, `lowerSetLiteral` and `lowerKeyedMethod`: maps
and sets under [[Native Maps and Sets]].

## Order and failures

Arguments run before the receiver, as every method call's do. `get` puts the
key in a local and builds `Some` or `None` in Core from a containment test and
a lookup, so no C code needs an Option's layout. Where the key type could hold
a function, every key is tested before it is stored, and one that cannot be
ordered fails with E7008 naming its kind as `valueKind` does (a sum by the
variant it holds): after all the members of a literal or `setOf`/`mapOf`
array, at the call for `insert`. Where it couldn't, no test is emitted.

## Resolved Grill Log

- **Q:** Why test in Core rather than in C? **A:** The message needs the
  variant name of a sum key, and Core already has `CoreVariantName` and
  `CoreFailText`.
- **Q:** Does `for` over a map snapshot it? **A:** Yes, `entries()` first, as
  `walkValues` lists the entries before the body runs.

## Dependencies and consumers

[[Compiler Lower Array]] · [[Compiler Lower State]] · [[Compiler Lower Types]] · [[Core IR]]

## Referenced by

[[Compiler Lower Body]] · [[Compiler Lower For]] · [[Native Maps and Sets]] · [[src/Pudu/Compiler/_MOC]]
