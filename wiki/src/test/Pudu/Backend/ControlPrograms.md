---
type: module
path: "@root/test/Pudu/Backend/ControlPrograms.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, test, backend, conformance]
aliases: [Backend Control Programs]
---

# Backend Control Programs

## Purpose and interface

`controlSuccessPrograms` and `controlRefusalPrograms` export named complete
Pudu modules for the byte-for-byte harness in [[Backend Native Tests]].
They pin the existing language's scalar loop control to native execution.

## Behavior and dependencies

The success corpus covers Int, Bool and unit loop results; plain and labelled
break/continue; nearest-first repeated labels; mutable while conditions;
control transfer from a while condition to an enclosing loop; break operands
that transfer to an outer loop or return; Never branch joins; short circuit
skipping transfers; discarded loop-body values and discarded break results;
and a divergent loop on a branch that execution does not take. Nested unit returns
pin return-operand transfer. Never operands cover both Boolean operator positions,
both numeric operand positions, unary operators, if conditions, assignments,
and call arguments; observable helper effects expose skipped later evaluation.
If-without-else values preserve unit results while retaining taken-branch print
effects. The corpus retains genuine-unit branch regressions and adds ordinary Int, Bool
and print-Result trailing values whose normal results must now be discarded. Never conditions in those values, print/display operands, and direct
Never bindings preserve their enclosing transfer. Condition counters and later
printing expose repeated conditions, lost effects and accidental branch execution. Mutable unit locals initialize
and assign from effectful unit-returning calls, then return the stored unit
through a unit entry; output pins both calls and their order.
Failure programs retain arithmetic failure and printed effects when a break
operand or a loop-body value is evaluated only for effects.

## Algorithm and negative logic

Sources use `Text.unlines`, ordinary checked syntax and the interpreter oracle.
Scalar-operand cases share a finite enclosing loop and print from callees to
make any evaluation after a transfer observable.
All executed loops terminate. A divergent expression appears only behind a
false branch, so the differential runner cannot hang on intended divergence.
Warnings such as W2002 for repeated labels are allowed; compiler errors never
are. No handmade Core or generated C is used.

## Resolved Grill Log

- **Q:** Does an if-without-else discard its branch effects? **A:** No; unit-valued bindings and returns run both taken and skipped branches through the interpreter oracle, retaining printing only from the taken branch. Branches end with a genuine unit expression and the repaired interpreter also discards ordinary scalar and Result trailing values.
- **Q:** May a transfer in a scalar operand be lowered as unit? **A:** No; finite examples put break, continue, and return in scalar contexts and compare the independent interpreter result and output. Nested return operands must preserve the inner transfer before the enclosing return.
- **Q:** Does an unused loop result permit skipping its operand? **A:** No; printed effects and arithmetic failures prove the operand executes before transfer.
- **Q:** How are label names checked? **A:** Nested loops repeat a label and separately transfer to an outer label; execution distinguishes nearest-first resolution from accidental textual matching.
- **Q:** Can a while condition transfer to its own loop? **A:** No; its loop frame exists only for the body. Condition cases transfer to an enclosing loop.
- **Q:** How can Never be covered without hanging? **A:** A direct break/return joins a reachable scalar branch; a truly divergent loop occurs only in a branch that is not taken.

## Referenced by

[[Backend Native Tests]] · [[Backend Emit Tests]] · [[src/_MOC]] · [[src/Pudu/Backend/_MOC]]
