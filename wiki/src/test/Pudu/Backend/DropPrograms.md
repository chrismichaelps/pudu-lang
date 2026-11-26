---
type: module
path: "@root/test/Pudu/Backend/DropPrograms.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, test, backend, ownership]
aliases: [Backend Drop Programs]
---

# Backend Drop Programs

## Purpose

Hold the two-engine drop corpus: programs whose drop traces the interpreter
and native code must print identically, and programs that stop with values
still owned.

## Interface

`dropSuccessPrograms :: [(String, Text, Text)]` and
`dropStopPrograms :: [(String, Text)]`.

## Algorithm

Every success program declares `Res` with a `Drop` implementation that prints
its name, and a `main` that exercises the ways ownership ends:

- a block that owns an inner value;
- a function that returns early;
- a `?` that leaves a function with an `Err`;
- `break` and `continue` inside a loop;
- a match that binds a payload;
- an assignment that replaces an owned value;
- a statement temporary and `let _ = value`;
- a moved local and a value passed back from a call;
- a value moved on one branch only, which the other branch still owns;
- a user `drop` on a record whose fields also need drop;
- a closure whose parameter owns a value, dropped when the closure ends;
- an async function and an async lambda whose parameters own values. Each is
  awaited once, the task drops its parameters when the body ends, and the
  parameters are dropped whether or not the body names them. Each await runs
  the body again, which adopts its parameters again, as the interpreter's
  per-await call does.

The expected trace is written by hand. It fixes the order: newest declaration
first within a scope, user `drop` before parts, parts in declaration order,
and replacement before the store.

The stop program panics in a callee while the caller still owns values; both
engines must print the values' drops before the panic report. It joins the
existing differential conformance property without a handwritten trace, so
the interpreter is the oracle.

## Negative Logic

No expected trace is copied from a native run. A trace that disagrees with
the interpreter fails the property rather than becoming the new expectation.

## Edge Cases

The success corpus is also counted for allocations: every allocation the drop
corpus makes must be released, so a drop that runs but leaks still fails.
Values that need no drop are not in the corpus; they keep the reading
semantics every program had.

## Resolved Grill Log

- **Q:** Why a handwritten trace for success programs? **A:** A differential
  test alone would accept two engines that agree on the wrong order.
  _Rationale:_ the trace pins the order the specification promises, and the
  interpreter comparison pins the rest.
- **Q:** Why no handwritten trace for the stop program? **A:** A panic's
  report includes a call site and the process status; the interpreter is the
  only oracle for that text. _Rationale:_ the drop order before the report is
  what the corpus is testing.
- **Q:** Why put the corpus in the counted-allocation harness too? **A:** A
  drop call that releases nothing would still match the trace. _Rationale:_
  the leak check is the other half of ownership.

## Referenced by

[[Backend Native Tests]] · [[Backend Text Leak Tests]] · [[Type Check Ownership Spec]] · [[Native Emission Coverage]]
