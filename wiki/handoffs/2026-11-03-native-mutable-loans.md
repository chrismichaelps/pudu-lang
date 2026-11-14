---
type: handoff
status: DONE
issue: 651
aliases: [Native Mutable Loans Delivery]
---
# Native Mutable Loans Delivery

Backend Engineer → Test Engineer → Forensic Guardian self-audit. Owned:
Compiler Lower Loan (new), Place's held places, Signature's loaned
parameters, the loan fields of State, Types' outer-`&mut` look-through,
Reference's dereference, the return cases of Body, Try's returning `?`,
Call's dispatch, Lower's body choice, Method's refusal span,
MutableLoanPrograms and mirror pages. No sub-agents. Branch
feature/651-native-mutable-loans on feature/649-native-element-assignment.

Evidence: every corpus program matches the tree interpreter byte for byte;
output-callable groups pass under Clang, GCC 15 and ASan/UBSan with zero
live allocations; every backend property label passes.

Exact next action: loans to methods. `value.bump()` with
`self: &mut Self`, and a method with `&mut` parameters, hold the receiver's
place (as `receiverOf` does: an element-chosen receiver through its place,
otherwise a plain name) and the arguments' places before the instance is
chosen, then reuse `lowerLoanedCall`'s writeback with the receiver first.

## Referenced by

[[handoffs/_MOC]] · [[Native Mutable Loans]]
