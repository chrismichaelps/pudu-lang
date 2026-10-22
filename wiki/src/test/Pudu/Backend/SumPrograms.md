---
type: module
path: "@root/test/Pudu/Backend/SumPrograms.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Sum Programs]
---
# Backend Sum Programs

## Purpose and interface

Export sumSuccessPrograms and sumRefusalPrograms, run by [[Backend Native
Tests]] and, for successes, [[Backend Text Leak Tests]].

## Coverage

Rendering of unit, positional and record variants, qualified constructors,
nested Option and Result payloads; equality by variant then payload, NaN
payloads included; `match` with ordered arms, guards, bindings, literal,
range, tuple, constructor, record and alternative patterns; Option and Result
through calls, loops and nested patterns; payload order and a Never payload;
sums through mutation and loop values; sum entry results; `if let` chains,
valued and value-less, with the subject run once; `while let` reading its
subject each turn, with `continue`, a labelled `break` out of a nested loop and
its unit value. Refusals: ordering, subtraction and addition on sums, each
naming the held variants after the operands ran; overflows inside an `if let`
body and a `while let` subject.

## Grill Log

- **Q:** Why do the `if let` and `while let` programs trace their subjects? **A:** Because lowering through a match must still read the subject exactly once per `if let` and once per `while let` turn; a print in the subject makes a second read visible (#540).

- **Q:** Why no refusal for a match no arm accepts? **A:** Checking requires
  every match to cover its subject, so E7011 cannot be reached from a checked
  program; both paths keep it only as a guard.
- **Q:** Why does one program walk a `while` rather than a `for`? **A:** `for`
  is part of the iteration row and not yet native; the program tests sums.

## Referenced by

[[Backend Native Tests]] · [[Backend Text Leak Tests]] · [[Native Emission Coverage]] · [[src/_MOC]]

## Refutable binding coverage

Resolved Grill Log: add hand-written expected outputs for a subject evaluated
once, fallback references to shadowed outer names, partial and alternative
patterns, sequential bindings, and labelled break/continue. Compare fallback
and subject failures with interpreter diagnostics, including source spans and
output before failure. Existing native, GCC, sanitizer and counted-allocation
runners consume these same programs. A failure path must never reach a use of
a success-only binding.

The subject may itself return before any pattern test; a regression retains
that return and never attempts to read the unreachable successful binding.
