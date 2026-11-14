---
type: handoff
status: DONE
issue: 791
aliases: [Native Blame Hook Delivery]
---
# Native Blame Hook Delivery

Backend Engineer → Forensic Guardian self-audit. Owned: the Runtime parts
table, Integer's and Dependencies' part edges, Frame's base parts and their
mirror pages. No sub-agents. Branch feature/791-native-blame-hook on
feature/790-native-method-loans.

Evidence: `native case mapping and trim agree with Data.Text on every
scalar` passes under Clang with -Werror; every backend property label
passes.

Exact next action: loans through function values. Give a function type with
`&mut` parameters a native form whose calls return the finals beside the
result, so `let f = bump; f(&mut n)` and lambdas with `&mut` parameters
write back as `dispatchCall` does.

## Referenced by

[[handoffs/_MOC]]
