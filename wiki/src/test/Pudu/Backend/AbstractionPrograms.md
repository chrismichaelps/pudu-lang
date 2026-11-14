---
type: module
path: "@root/test/Pudu/Backend/AbstractionPrograms.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Abstraction Programs]
---
# Backend Abstraction Programs

Export abstractionSuccessPrograms and abstractionRefusalPrograms. Success
programs cover static members through a type parameter with written and
inferred arguments and generic implementations, sequence patterns in `let`
at every depth, dynamic values (widening at each expectation site, dispatch
with defaults and arguments, nesting, rendering and equality) and
constructor parameters of one and two arguments, plain and through a trait.
Refusal programs pin E7013 for a sequence of another length, top-level and
nested in a record.

## Resolved Grill Log

Every expectation is what the interpreter prints for the same program. All
success programs also run under the counted-allocation harness.

## Referenced by

[[Backend Native Tests]] · [[Backend Text Leak Tests]] · [[Native Type Abstractions]]
