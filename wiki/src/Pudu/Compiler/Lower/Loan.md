---
type: module
path: "@root/src/Pudu/Compiler/Lower/Loan.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Loan]
---
# Compiler Lower Loan

## Purpose and interface

Export lowerLoanedBody, loanedReturn, loanedValue and lowerLoanedCall.
lowerLoanedBody records the loaned parameter locals in the state, lowers the
body through the lowerer it is given (plain or defaulted), and makes the
trailing result the tuple of the result and each loaned local; the
function's Core result becomes that tuple's type. loanedReturn builds the
same tuple for a `return`, with or without a value, and loanedValue for any
value leaving the function, which [[Compiler Lower Try]] uses for a
returning `?`. lowerLoanedCall lowers a call to a function with loans.

## Algorithm and invariants

- The value leaving is held in a temporary before the finals are read, so a
  `return` whose value assigns a loaned parameter is seen, as
  `runClosureKeeping` reads the frame after the body.
- A value of type Never answers nothing and is left alone; a body whose
  statements never finish keeps no trailing tuple.
- At the call, every argument is held in a temporary, in order. One at a
  loaned position written `&mut place`, or naming a local lent on, is held
  through [[Compiler Lower Place]]: its indices run there, once, and the
  place is read at the root span. Any other argument is an ordinary value
  with no writeback.
- After the call the tuple is held; each final is stored through its place,
  in parameter order, reading the root again; the call's value is the
  tuple's first member. A loaned parameter a call left to its default is
  not written anywhere.
- An argument that stops leaves the call unmade.

## Negative logic

A lent place whose type differs from the parameter's refuses ("lending a
place of a different type"); checking makes this unreachable today.
`lowerLoaned` is reset by `startFunction`, so a lambda or method-value body
inside a loaned function returns its own value.

## Resolved Grill Log

- **Q:** Pass the place by pointer? **A:** No; a place may be a field or
  element of a shared, reference-counted value, and exclusivity (E3081,
  E3084) already keeps anything else from observing it during the call.
- **Q:** Hold every argument, not just the lent ones? **A:** Yes; a later
  argument's index must run after an earlier argument's effects, as the
  evaluator's `mapM argumentOf` orders them.

See [[Native Mutable Loans]].

## Dependencies and consumers

Uses [[Compiler Lower Place]], [[Compiler Lower Default]], [[Compiler Lower Control]] and [[Compiler Lower State]]. Used by [[Compiler Lower]], [[Compiler Lower Body]], [[Compiler Lower Try]] and [[Compiler Lower Call]].

## Referenced by

[[Compiler Lower]] · [[Compiler Lower Body]] · [[Compiler Lower Try]] · [[Compiler Lower Call]] · [[Native Mutable Loans]] · [[src/Pudu/Compiler/_MOC]]
