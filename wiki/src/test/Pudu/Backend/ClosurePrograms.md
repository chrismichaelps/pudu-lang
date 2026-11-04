---
type: module
path: "@root/test/Pudu/Backend/ClosurePrograms.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Closure Programs]
---
# Backend Closure Programs

Exports closureSuccessPrograms (label, source, expected stdout) and
closureRefusalPrograms (label, source), for [[Native Closures]].

Resolved Grill Log: captures of text and records taken before both are
reassigned; closures through generic higher-order functions, returned from
functions and composed; closures in records and tuples and named functions as
values, with their `<fn name>` rendering; equality by written place; lambdas
inside a generic body, nested lambdas and recursion through a passed function;
arguments running before the callee value, including an argument that
reassigns the callee's variable. The refusals are tuple ordering over held
functions (an E7001 after both operands ran, while an absent function still
orders) and an overflow inside a lambda body.

## Referenced by

[[Native Closures]] · [[Backend Module Programs]] · [[Backend Text Leak Tests]]
