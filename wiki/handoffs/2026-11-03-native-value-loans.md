---
type: handoff
status: DONE
issue: 794
aliases: [Native Value Loans Delivery]
---
# Native Value Loans Delivery

Backend Engineer → Test Engineer → Forensic Guardian self-audit. Owned:
Types' loaned function types, Loan's callees and body closing, Lambda's
value calls and lambdas, MethodValue's lifted loans, Method's direct
callee, the value programs in MutableLoanPrograms, the EmitSpec and
LowerTypesSpec cases and mirror pages. No sub-agents. Branch
feature/794-native-value-loans on feature/791-native-blame-hook.

Evidence: every corpus program matches the tree interpreter byte for byte;
output-callable groups pass under Clang, GCC 15 and ASan/UBSan with zero
live allocations; every backend property label passes.

Exact next action: superseded by [[Native Dev Sync Delivery]]; trait-
qualified method values are rejected by dev's checker (#795, #797 closed).

## Referenced by

[[handoffs/_MOC]] · [[Native Mutable Loans]]
