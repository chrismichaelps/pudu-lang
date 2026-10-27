---
type: handoff
status: ACTIVE
issue: 646
aliases: [Native Trait Method Value Delivery]
---
# Native Trait Method Value Delivery

Backend Engineer → Test Engineer → Forensic Guardian self-audit. Owned:
Compiler Lower MethodValue, closure helpers, the MethodValuePrograms
additions and their mirror pages. No sub-agents. Branch
feature/646-native-trait-method-values on feature/644-native-method-values.

Evidence: the trait-method programs match the tree interpreter byte for
byte, including a failure inside the implementation at its own span. The
output-callable groups pass under Clang, GCC 15 and ASan/UBSan; method,
record, sum, field, lowering and refusal groups pass.

Found: #647, the interpreter fails a trait-qualified method value.

Exact next action: read the unchanged gate run at the #644 tip and fix any
failure; then pick the next ledger row. Callables now lack only other
builtin values, higher-kinded parameters and `dynamic` values; the larger
open rows are Errors/references/resources (mutable loans, moves, drop) and
host services.

## Referenced by

[[handoffs/_MOC]] · [[Native Method Values]]
