---
type: module
path: "@root/test-fixtures/stdlib/RejectsOptionUnwrapMethodImported.pudu"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
grammar: "[[grammar/pudu]]"
tags: [module, fixture, option, regression]
aliases: [Rejects Option Unwrap Method Imported]
---

# Rejects Option Unwrap Method Imported

## Purpose and interface

Issue #383 regression fixture. Imports `Std.Option as Option` and calls `unwrapOr` on an `Option[Int]` value. The checker must report exactly one `E3005` naming `unwrapOr`; importing module functions cannot grant receiver methods.

## Algorithm and boundaries

`main` isolates one call shape with an explicit `Option[Int]` annotation, preventing inference or another module from supplying the behavior under test. [[Standard Library Program Spec]] asserts structured diagnostics or the exact rendered result.

## Negative logic and edge cases

`Option` remains a prelude sum type; the module alias is an independent namespace binding. No implicit module-function-to-method conversion is admitted. Present and absent values must use the same declared call contract.

## Grill Log

- **Q:** Does importing the Option module make its exports receiver methods? **A:** No; [[grammar/pudu]] requires module-qualified function calls and reserves method lookup for wired-in methods and explicit implementations. _Rejected:_ accepting a call that reaches no runtime method.
- **Q:** Why state the value's type? **A:** The regression concerns method admission on `Option[Int]`, independent of constructor inference. _Rejected:_ relying on an unconstrained `None`.

## Referenced by

[[Standard Library Program Spec]] · [[Std Option]]
