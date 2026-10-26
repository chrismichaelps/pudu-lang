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

## Method corpus (#551)

Resolved Grill Log: modulePrograms and moduleRefusalPrograms include
[[Backend Method Programs]] the same way as the reference corpus.

## Generic corpus (#552)

Resolved Grill Log: both lists include [[Backend Generic Programs]].

## Try corpus (#553)

Resolved Grill Log: both lists include [[Backend Try Programs]].

## For corpus (#554)

Resolved Grill Log: both lists include [[Backend For Programs]].

## Closures (#555)

Resolved Grill Log: both lists include [[Backend Closure Programs]].

## Array corpus (#556)

Resolved Grill Log: both lists include [[Backend Array Programs]].

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

## Shared reference corpus (#544)

Resolved Grill Log: include [[Backend Shared Reference Programs]] in the actual
modulePrograms/moduleRefusalPrograms lists, supplying no dependency files for
these single-module programs. The existing native conformance coordinator
executes them with their locked outputs; no unused property list counts.
