---
type: handoff
status: ACTIVE
issue: 641
aliases: [Native Qualified Value Delivery]
---
# Native Qualified Value Delivery

Backend Engineer → Test Engineer → Forensic Guardian self-audit. Owned:
the member-expression guard in Compiler Lower Body, one module program and
their mirror pages. No sub-agents. Branch feature/641-native-qualified-values
on feature/638-native-defaults.

Implementation: a member expression whose receiver is a module qualifier
and whose member resolves to a module function lowers through
lowerFunctionValue, as a bare name does.

Evidence: the module program matches both evaluators under Clang and
ASan/UBSan; refusal, lowering, member and field groups pass.

Open alongside: #639 (defaults read the caller's module) is fixed on
feature/639-default-scope from dev, pending its PR; #634 (panic untyped)
needs Language Architect review. The release gate at the #638 tip is
running unchanged in a detached worktree.

Exact next action: read the #638 gate result and fix any failure; then pick
the next Callables gap, method values (`"x".length` or `list.push` as values),
probing the interpreter first.

## Referenced by

[[handoffs/_MOC]] · [[Native Emission Coverage]]
