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

## Referenced by

[[Native Mutable Loans]] · [[src/Pudu/Backend/_MOC]]
