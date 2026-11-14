---
type: module
path: "@root/test/Pudu/Backend/RecordPrograms.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Record Programs]
---
# Backend Record Programs

## Purpose and interface

Export recordSuccessPrograms and recordRefusalPrograms, run by [[Backend
Native Tests]] and, for successes, [[Backend Text Leak Tests]].

## Coverage

Rendering in declaration order whatever order was written (#519), nested and
empty records; field-by-field equality; field reads and updates; written-order
field effects and base-first updates; field assignment, nested paths, and an
assigned value that reassigns the local; records through calls, loops,
branches, `break` values and `let {..}` patterns; a Never field; record entry
results. Refusals: ordering, arithmetic and negation on records, after their
operands run.

## Grill Log

- **Q:** Why an empty record? **A:** Zero members exercise the C edge cases
  (no parameters, no parts) the helpers special-case.

## Referenced by

[[Backend Native Tests]] · [[Backend Text Leak Tests]] · [[src/_MOC]]
