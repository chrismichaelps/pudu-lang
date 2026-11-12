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
the callee value running before arguments, including an argument that
reassigns the callee's variable. The refusals are tuple ordering over held
functions (an E7001 after both operands ran, while an absent function still
orders) and an overflow inside a lambda body.

Resolved Grill Log (#828): the computed callee prints before its argument.
Replacing a mutable function binding inside an argument affects the next
call and leaves the in-flight call using its retained target. A transfer in\nthe callee skips its arguments, and a transfer in an argument skips invocation.

## Referenced by

[[Native Closures]] · [[Backend Module Programs]] · [[Backend Text Leak Tests]]
