---
type: handoff
status: DONE
issue: 644
aliases: [Native Method Value Delivery]
---
# Native Method Value Delivery

Language Architect → Backend Engineer → Test Engineer → Forensic Guardian
self-audit. Owned: Compiler Lower MethodValue (new), the Body hook, the
Types fact overlay, CoreClosureInfo.closureMethod, closure helpers, the frame
table's blames flag, the runtime blame hook and report relocation, the
MethodValuePrograms corpus and matching vault pages. No sub-agents. Branch
feature/644-native-method-values on feature/641-native-qualified-values.

[[Native Method Values]] was resolved before source changes.

Evidence: every corpus program matches the tree interpreter byte for byte,
including failures relocated to the call through the value. The output
callable groups pass under Clang, GCC 15 and ASan/UBSan with zero live
allocations; refusal, diagnostic, frame, runtime, wide, float, lowering,
emit, module, text, array, keyed, range, bytes and pipe groups pass.

The unchanged gate at the #638 tip passed everything but the
diagnostic-code check: E7007 was spelled in both Lower.Stop and the
evaluator. A follow-up commit moves the panic and untyped convertInteger
wording into Pudu.Diagnostic.Evaluation so each code is written once.

Exact next action: rerun test/gates.sh unchanged at this branch's tip;
then trait and user-declared methods as values (`value.label` where label
comes from an impl), probing the interpreter first.

## Referenced by

[[handoffs/_MOC]] · [[Native Method Values]]
