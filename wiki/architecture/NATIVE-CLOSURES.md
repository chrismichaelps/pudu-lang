---
type: architecture
status: IMPLEMENTED
tags: [architecture, backend, closures]
aliases: [Native Closures]
---
# Native Closures

A function value is a refcounted box. Cell 0 holds the frame-table number of
the lifted function it runs, and the captures follow in cell order.

## Contract

- **Construction.** [[Compiler Lower Lambda]] lifts each lambda into a
  function whose first parameter is the closure, and the closure copies the
  enclosing locals the lambda mentions. A named function used as a value is a
  closure naming its actual target, with no forwarding frame (#568).
- **Calls.** `CoreCallValue` evaluates the callee, then the arguments.
  Lowering orders the source's arguments before the callee with temporaries.
  The frame step takes its callee from cell 0. Explicit environment metadata
  passes the box as argument 0 only to lifted lambda bodies. Named targets
  receive their actual arguments and count one source call, with the invocation
  site retained for E7002. See [[Native Named Callable Dispatch]].
- **Lifetime.** Each function type has a `CoreClosureLayout` listing every
  lifted function whose closure has that type. Its drop helper switches on cell
  0 to release that function's captures by kind.
- **Observation.** `show`/`display` write `<fn name>` (`<fn <fn>>` for a
  lambda). Equality compares the place each was written. Ordering ranks two
  functions alike, and a tuple holding a function anywhere fails ordering with
  E7001, as `comparableValue` decides at run time.

## Found on the way

Ordering tuples compared record and sum members by pointer since #521/#525.
They now compare as `compareValues` does: records field by field, sums by
variant name, then payload.

## Not yet

The four output builtins retain their distinct builtin identity and use
uncounted intrinsic frames ([[Native Output Callable Values]]). Other builtin
values remain incomplete.

Method values (`value.method` without a call), async lambdas and default
parameter values refuse with E6001.

## Resolved Grill Log

- Box the closure rather than specialize on it: a function value can be
  stored, returned and called far from where it was made.
- Equality by site, not by function number: copies of one lambda in two
  specializations are the same function to the evaluator.

## Referenced by

[[Native Emission Coverage]] · [[Compiler Lower Lambda]] · [[Backend Closure Programs]]
