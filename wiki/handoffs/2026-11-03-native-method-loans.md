---
type: handoff
status: ACTIVE
issue: 790
aliases: [Native Method Loans Delivery]
---
# Native Method Loans Delivery

Backend Engineer → Test Engineer → Forensic Guardian self-audit. Owned:
Method's instanceTarget and loaned calls, Loan's ordered operands,
Generic's reference matching, the method programs in MutableLoanPrograms,
EmitSpec's refusal table and mirror pages. No sub-agents. Branch
feature/790-native-method-loans on feature/651-native-mutable-loans.

Evidence: every corpus program matches the tree interpreter byte for byte;
output-callable groups pass under Clang, GCC 15 and ASan/UBSan with zero
live allocations; every backend property label passes except the
pre-existing runtime warning (#791) and a cancellation timing check that
passes alone.

Exact next action: fix #791 (the runtime's unused `pudu_blame_hook` under
-Werror), then loans through function values: give a function type with
`&mut` parameters a native form whose calls return the finals beside the
result, so `let f = bump; f(&mut n)` and lambdas with `&mut` parameters
write back as `dispatchCall` does.

## Referenced by

[[handoffs/_MOC]] · [[Native Mutable Loans]]
