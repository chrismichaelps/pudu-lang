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

## Referenced by

[[Native Maps and Sets]] · [[Backend Module Programs]] · [[Backend Text Leak Tests]]
