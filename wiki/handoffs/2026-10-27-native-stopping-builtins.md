---
type: handoff
status: DONE
issue: 633
aliases: [Native Stopping Builtin Delivery]
---
# Native Stopping Builtin Delivery

Language Architect → Backend Engineer → Test Engineer → Forensic Guardian
self-audit. Owned: Compiler Lower Stop (new), Intrinsic, Body dispatch, the
runtime reporter's empty-message rule, StoppingBuiltinPrograms, the moved
EmitSpec/FunctionPrograms case and matching vault pages. No sub-agents.
Branch feature/633-native-panic, draft PR #635 on feature/631.

[[Native Stopping Builtins]] was resolved before source changes. Probing
found that checking never binds panic; filed as #634. Native takes panic's
signature only where it is certain and refuses elsewhere.

Evidence: every corpus program matches the tree interpreter byte for byte,
including empty and multi-line messages, non-text and missing arguments and
calls through values. The output-callable, refusal, function and scalar
groups pass under Clang, GCC 15 and ASan/UBSan. Two pre-existing suite
failures surfaced and moved to #636.

## Referenced by

[[handoffs/_MOC]] · [[Native Stopping Builtins]]
