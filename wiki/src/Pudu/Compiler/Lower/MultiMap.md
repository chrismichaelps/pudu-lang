---
type: module
path: "@root/src/Pudu/Compiler/Lower/MultiMap.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Multi Map]
---
# Compiler Lower Multi Map

Export multiMapBody: the Core for `multiMapAdd` or `multiMapContains` over
three operands already in hand, or Nothing when the signature is not the
primitive's. The first operand must be a record whose layout has
`groups: Map[K, Array[V]]` and `occurrences: Map[(K, V), Int]`, with the
other operands typed K and V.

Add holds the operands in locals, tests the key and then the pair with the
shared orderability statement, appends to a group found by one lookup with
an empty default, increments a count found by one lookup with a zero default,
and answers the record with both maps replaced
through `KeyedPut`. Contains is `KeyedContains` of the pair.

## Resolved Grill Log

The record layout is read from solved facts; a different shape refuses
rather than guessing fields. Failure order is key, pair, count, as the
interpreter reports them. A blame flag chooses the call span or the caller
site, so a refusal through a value names the call made through it.
An existing group remains owned by its original map. Appending a value has
the same copy-on-write boundary as any other array update.

## Referenced by

[[Compiler Lower Store]] · [[Native Indexed Stores]]
