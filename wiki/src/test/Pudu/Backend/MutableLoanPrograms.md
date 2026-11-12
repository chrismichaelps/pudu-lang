---
type: module
path: "@root/test/Pudu/Backend/MutableLoanPrograms.hs"
fidelity: Active
aliases: [Backend Mutable Loan Programs]
---
# Backend Mutable Loan Programs

Export mutableLoanSuccessPrograms and mutableLoanRefusalPrograms.
Successes lend locals, fields, elements, element fields and nested
elements; write back after early return, `?` on Result and Option, a bare
`return` and a returning loop; swap two fields of one record, lend a loaned
parameter on twice, print in index order and recurse fifty deep; combine
loans with defaults, generic copies and an unrelated binding; and lend an
owned Str field and an array 200 times. Failures cover a lent element out
of range at the root name before the call, a division failure inside the
callee after it assigned its parameter, loaned recursion past the call
depth, and a panicking index.

## Resolved Grill Log

Expectations come from the tree interpreter and are rechecked against the
compiled evaluator; healthy programs also run under counted allocation.

## Dependencies and consumers

[[Backend Output Callable Programs]] · [[Backend Native Tests]] · [[Backend Text Leak Tests]] · [[Pudu Test Cabal Manifest]]

Resolved Grill Log (#828): the computed loaned callee prints before its
argument index. The final lent value and writeback are checked independently
of the ordering trace.

## Referenced by

[[Native Mutable Loans]] · [[src/Pudu/Backend/_MOC]]

## Method loans (#790)

Successes add receiver and argument loans with a qualified trait call and
an element receiver whose index runs before the argument; generic,
inherited and fallible methods on nested receivers; and a loaned method held
as a value. A failure adds an element receiver out of range, reported at
its root before the argument runs.

## Loans through values (#794)

Successes add named functions, parameters typed `fn(&mut Int) -> Int`,
lambdas and arrays of loaned functions; bound and type-qualified method
values with `&mut` inputs, lambdas with `return`, `?` and captures, a callee
that runs before an element argument, a record field, a generic
higher-order function and a defaulted function value. A failure adds an
element out of range lent through a value, after the callee ran.

Resolved Grill Log (#828): A receiver index runs before the supplied argument. A bad receiver index fails at the root before any supplied argument effects.
