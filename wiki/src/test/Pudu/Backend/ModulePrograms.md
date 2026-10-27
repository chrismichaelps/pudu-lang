---
type: module
path: "@root/test/Pudu/Backend/ModulePrograms.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Module Programs]
---
# Backend Module Programs

## Purpose and interface

Export modulePrograms and moduleRefusalPrograms, run by [[Backend Native
Tests]] through `conformanceWith`, which writes each module beside the root.

## Coverage

Calls through a selective import, an alias and a module that itself imports
another; a library's private helper; recursion inside a library; a record and
a sum declared in another module, including as an entry result; a record and a
sum declared in two modules under one name. Refusal: an overflow inside an
imported function, reported at that module's source.

## Referenced by

[[Backend Native Tests]] · [[Native Emission Coverage]] · [[src/_MOC]]

## Folded constant corpus (#543)

Resolved Grill Log: export constantPrograms for ordinary single-module cases,
include them in modulePrograms, and reuse them in counted allocation tests.
Cover compile-time calls/prior values, aliases, wide integers, Float32/-zero/NaN,
owned tuples/records/sums, repeated reads, transfers and unused unsupported
constants. Cross-module cases cover selected imports, aliases, transitive
reads and same-spelling aggregate types/constants. Failure cases retain
reference/operation source provenance after reading a folded value.
