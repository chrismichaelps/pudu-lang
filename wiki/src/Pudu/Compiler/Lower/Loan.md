---
type: module
path: "@root/src/Pudu/Compiler/Lower/Loan.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Loan]
---
# Compiler Lower Loan

Resolved Grill Log. Loaned calls select their body from the retained
argument layouts. An incompatible concrete layout takes the same
specialization path as a runtime alternative.

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

- **Q:** Why do a lent receiver and a lent argument report at different spans?
  **A:** A receiver is chosen by its key like any element read, whatever its
  method does; an argument written `&mut place` names a place to write back,
  and writes report at the root.

See [[Native Mutable Loans]].

## Dependencies and consumers

Uses [[Compiler Lower Place]], [[Compiler Lower Default]], [[Compiler Lower Control]] and [[Compiler Lower State]]. Used by [[Compiler Lower]], [[Compiler Lower Body]], [[Compiler Lower Try]] and [[Compiler Lower Call]].

Resolved Grill Log (#828): snapshot every value callee before preparing
any operand. A direct receiver call prepares parameter zero first and
retains its lent place. Writeback follows parameter position after invocation.

## Resolved Grill Log for #877 — Native loan lowering

Build foreign calls from the same held-operand traversal as language calls. The foreign crossing supplies the result and final tuple; place lookup and writeback remain here.

## Resolved Grill Log for #877 — Post-call settlement

A foreign call checks its captured report after the ordered stores and before reading the result.

## Referenced by

[[Compiler Lower]] · [[Compiler Lower Body]] · [[Compiler Lower Try]] · [[Compiler Lower Call]] · [[Native Mutable Loans]] · [[src/Pudu/Compiler/_MOC]]

## Ordered operands (#790)

Also export Operand and lowerLoanedOperands: operands come in the order
they run, each with its parameter position and whether it is an argument or
a method receiver. A receiver at a loaned position lends any place it
names, read with readHeldAtKeys; an argument only `&mut place` or a local lent
on, read with readHeld. The call passes
operands by position and stores finals in parameter order, so a receiver
is written back first, as `callClosureLending` lists
`lentSelf` first. lowerLoanedCall is the case of arguments in order.

## Calls through values (#794)

Also export Callee, valueSignature and closeLoaned. A loaned call reaches a
`Direct` function by name, queued only when the call is made, or `Through`
an ordinary value held before its operands, as `evaluateCall` orders it; a value
that stops leaves the call unmade. valueSignature builds the signature a
value call reads from its formed function type. closeLoaned makes a body's
trailing result answer the finals; lambdas and lifted method values use it.

## Ordinary operands of loaned calls (#956)

Resolved Grill Log: when a loaned call has an ordinary operand, widen it
using the corresponding expected parameter carrier before binding it.
A lent place must retain its exact carrier for writeback.

## Native mutable loan layouts (#956)

Resolved Grill Log: Read each place once at its argument position. Select the exact native parameter and final layouts before the call. Project finals back into their retained places in parameter order.

## Layout demands from a lent parameter (#956)

Resolved Grill Log: a named parameter may demand a broader layout
through an assignment. The caller projects its input and records any
layout it needs to hold the resulting final.

## Stored mutable parameter layouts (#956)

Resolved Grill Log: A held operand may project into a wider loaned input without copying the callable. The return path still publishes the final into its original place.

## Selected indirect loan profiles

Resolved Grill Log: retain explicit places and possible forwarded
names in operand order. The callable identity decides the written
parameter count and which positions publish finals. A failing arity
check runs after operand effects and before any final store.

[[Compiler Lower Default]] · [[Backend Rendering Callable Programs]]

Resolved Grill Log: an already retained indirect callee uses the
same operand traversal as a written one. No path reevaluates the
callee to discover its constraints.

## Retained declared receiver places

Resolved Grill Log: start selected direct method calls with the
already evaluated receiver and its original place at parameter zero.
Check arity after the remaining arguments run and before queueing
the body or publishing any finals.

Resolved Grill Log: a prepared place read can select a slice and
therefore reserve native locals before collecting later arguments.
