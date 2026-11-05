---
type: module
path: "@root/test/Pudu/Backend/ModulePrograms.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Module Programs]
---
# Backend Module Programs

Word-map algebra (#810): register successes and refusals from [[Backend Word Map Programs]] in the ordinary module corpora. Resolved Grill Log: focused
groups supplement these complete gates rather than replacing existing cases.
## Complete carried frozen data (#808)

Export constantModulePrograms and constantRefusalPrograms alongside the
single-module constantPrograms. Include all three in the ordinary module
corpora and focused native folded-constant groups. Cover nested arrays,
maps, sets and ranges, typed empty collections, mutation without changing
the original constant, imported aliases and canonical record owners.
Refusals retain indexing/range/operation provenance after reading constants.

Resolved Grill Log: expected outputs are handwritten and independent of the
evaluator and emitter. Only library-free successes enter counted cleanup;
multi-module cases use the real compiler/module-loading harness.

## Purpose and interface

Export modulePrograms and moduleRefusalPrograms, run by [[Backend Native Tests]] through `conformanceWith`, which writes each module beside the root.

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

## Array patterns (#558)

Includes [[Backend Array Pattern Programs]] in both the success and refusal
lists.

## Text collections (#559)

Includes [[Backend Text Collection Programs]] in both lists.

## Conversions (#560)

Includes [[Backend Convert Programs]] in both lists.

## Maps and sets (#561)

Includes [[Backend Keyed Programs]] in both lists.

## Shapes (#563)

Includes [[Backend Shape Programs]]' single-module programs and its
multi-module ones.

## Range values (#564)

Includes [[Backend Range Programs]] in both lists.

## Bytes (#565)

Includes [[Backend Bytes Programs]] in both lists.

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

## Rendering intrinsic ownership (#575)

Include renderingCallableModulePrograms from [[Backend Rendering Callable Programs]].
Resolved Grill Log: two modules' same-spelling record types require distinct
rendering bodies, even when their builtin identity and displayed names agree.

## Default parameters (#638)

Register defaultParameterModulePrograms. Resolved Grill Log: literal
defaults only until #639.

## Qualified function values (#641)

A module program takes `Lib.twice` and `L.twice` as values, passes one to a
higher-order function, renders and compares them, and binds a defaulted
qualified function. Resolved Grill Log: a local cannot share a qualifier's
name (qualifiers are capitalized, and a capitalized let is a pattern), so no
shadowing case is needed.

## Native byte views (#827)

Include success and refusal cases from [[Backend Text View Programs]] in the complete module corpora without replacing existing cases. See [[Native Text Views]].

## Imported trait defaults (#824)

An importer inherits `loudly`, `wrapped` and `twice` from `Lib.Loud`.
`loudly` calls `Lib`'s private `shout` while the importer declares its own
`shout`, and one implementation overrides `twice`. Calls go through method
syntax and the trait-qualified form.

Resolved Grill Log (#824): an imported inherited default divides by a runtime
zero from its implementation. Its refusal must retain the trait module's
source span and output ordering in both evaluator modes and native execution.
