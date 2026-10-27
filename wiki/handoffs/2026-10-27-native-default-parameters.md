---
type: handoff
status: ACTIVE
issue: 638
aliases: [Native Default Parameter Delivery]
---
# Native Default Parameter Delivery

Language Architect → Backend Engineer → Test Engineer → Forensic Guardian
self-audit. Owned: Compiler Lower Default (new), Signature, Call, Lambda,
Types, Lower, the Body export, Core/Frame zero values and their emission,
DefaultParameterPrograms, its registrations, the EmitSpec table and matching
vault pages. No sub-agents. Branch feature/638-native-defaults on
feature/636-native-suite-repairs.

[[Native Default Parameters]] was resolved before source changes. Probing
found the interpreter reads a default's names in the caller's module; filed
as #639 and kept out of the corpus.

Evidence: every corpus program matches the tree interpreter byte for byte,
including E7002 at a default's own call and failures inside defaults. The
output-callable and module groups pass under Clang, GCC 15 and ASan/UBSan
with zero live allocations; refusal, lowering, frame, emit, function,
generic, closure and method groups pass.

Exact next action: fix #639 on its own branch from dev (evaluate a default in
the declaring module's environment), then add a cross-module constant default
to the default corpus here; after that, module-qualified function values
(`let p = Lib.pad`) are the next Callables gap.

## Referenced by

[[handoffs/_MOC]] · [[Native Default Parameters]]
