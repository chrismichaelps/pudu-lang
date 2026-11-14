---
type: module
path: "@root/test/Pudu/Backend/StorePrograms.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Store Programs]
---
# Backend Store Programs

Export storeSuccessPrograms, storeModulePrograms and storeRefusalPrograms.
Success programs carry independent handwritten output for every store
method, persistence of earlier stores, owned payloads, equality and
ordering, method values, builtin identity, argument order and transfers,
key narrowing through `mixHash`, `hashOf` over every carrier, folded store
constants and large persistent stores. Module programs import
`Std.HashMap` and `Std.MultiMap` and cover `multiMapAdd`/`multiMapContains`
directly and as values. Refusal programs pin unorderable MultiMap keys and pairs, the
checked occurrence count directly and through a value, ordering operators
on stores, entries and argument failures.

## Resolved Grill Log

No program prints a mixed hash: the seed differs between the interpreter
and the native process. The corpus joins the existing differential and
counted-allocation harnesses rather than adding a runner.

## Referenced by

[[Backend Native Tests]] · [[Backend Text Leak Tests]] · [[Backend Module Programs]] · [[Native Indexed Stores]]
