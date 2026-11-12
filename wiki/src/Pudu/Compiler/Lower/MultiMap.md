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
shared orderability statement, builds the group (`lookup.push(value)` when
the key is held, `[value]` otherwise), builds the count (`lookup + 1`
checked at the call, or 1), and answers the record with both maps replaced
through `KeyedPut`. Contains is `KeyedContains` of the pair.

## Resolved Grill Log

The record layout is read from solved facts; a different shape refuses
rather than guessing fields. Failure order is key, pair, count, as the
interpreter reports them. A blame flag chooses the call span or the caller
site, so a refusal through a value names the call made through it.

## Referenced by

[[Compiler Lower Store]] · [[Native Indexed Stores]]
