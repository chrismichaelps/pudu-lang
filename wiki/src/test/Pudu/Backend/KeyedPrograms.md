---
type: module
path: "@root/test/Pudu/Backend/KeyedPrograms.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Keyed Programs]
---
# Backend Keyed Programs

Exports keyedSuccessPrograms and keyedRefusalPrograms, for
[[Native Maps and Sets]].

Resolved Grill Log: every map and set method; duplicates in `mapOf`, `setOf`
and literals; overwrites keeping the first key, `-0.0` and `0.0` as one key;
record, sum, tuple, Str, float and nested-collection keys; merges and set
algebra with overlaps and empties; maps inside tuples compared and rendered;
maps through records, parameters, references and an entry result, with copies
taken before updates; and three thousand inserts and removes in scattered
order. The refusals are E7008 for a function-holding key in `mapOf`, in a
literal (named by its variant), and in `insert` for record and array keys, and
E7001 for ordering tuples holding maps of functions.

Resolved Grill Log (#828): guarded lookup retains a map across argument
rebinding. Guarded insertion checks the key after receiver, key and value
effects finish in that order.

## Referenced by

## Cases

- set membership with `in`: candidate before set, key shapes, a set read through a reference, the empty set (#948)

## Referenced by

[[Native Maps and Sets]] · [[Backend Module Programs]] · [[Backend Text Leak Tests]]

## Dynamic key diagnostics (#956)

Resolved Grill Log: reject a dynamic key holding a generic record with
a function field. Name the held record after its initializer effects run.

## Runtime keyed layouts (#956)

Resolved Grill Log: cover selected values in construction, lookup, update and iteration, including retained aliases and missing keys.

## Held updates (#1019)

A new program, "map and set updates held once rewrite their own tree, and a shared map or set keeps its contents", runs `insert`, `put` and `remove` on a map that is held once, and copies a map with `let` before the updates so the copy is shared.

Resolved Grill Log: the program covers both the owned path and the copy path, so a change to the count test cannot silently alter a shared value.
